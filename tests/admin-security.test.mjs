import test from 'node:test';import assert from 'node:assert/strict';
import {validAdminOrigin,validCsrf,boundedJson} from '../src/lib/server/admin/security.ts';
test('CSRF accepts only an exact random token; rejects missing, altered and Unicode tokens',()=>{
 const token='a'.repeat(64);assert.equal(validCsrf(token,token),true);
 for(const candidate of ['', 'a'.repeat(63),'b'.repeat(64),'é'.repeat(64)])assert.equal(validCsrf(token,candidate),false);
});
test('origin comparison accepts the local Host and rejects cross-site or malformed origins',()=>{
 assert.equal(validAdminOrigin('http://127.0.0.1:3000','127.0.0.1:3000','same-origin',true),true);
 for(const origin of [null,'null','https://evil.example','http://127.0.0.1:3000/path','http://user@127.0.0.1:3000'])assert.equal(validAdminOrigin(origin,'127.0.0.1:3000','same-origin',true),false);
 assert.equal(validAdminOrigin('http://127.0.0.1:3000','127.0.0.1:3000','cross-site',true),false);
 assert.equal(validAdminOrigin('https://admin.example','admin.example','same-origin',false),true);
 assert.equal(validAdminOrigin('http://admin.example','admin.example','same-origin',false),false);
});
test('JSON body bound is enforced on received bytes, even without Content-Length',async()=>{
 const good=new Request('https://admin.example',{method:'POST',body:'{"name":"draft"}'});assert.deepEqual(await boundedJson(good),{name:'draft'});
 const oversized=new Request('https://admin.example',{method:'POST',body:JSON.stringify({name:'x'.repeat(200)})});await assert.rejects(boundedJson(oversized,100));
 for(const value of ['[]','null','"text"','{bad'])await assert.rejects(boundedJson(new Request('https://admin.example',{method:'POST',body:value})));
});
