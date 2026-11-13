import test from 'node:test';
import assert from 'node:assert/strict';
import {validateReview} from '../src/lib/server/reviews/validation.ts';
const valid={name:'Synthetic reviewer',rating:4,body:'Synthetic review text for a test.'};
test('review accepts optional contact/title and keeps plain text',()=>{assert.deepEqual(validateReview(valid),{...valid,title:'',email:''});assert.equal(validateReview({...valid,email:'synthetic@example.invalid'}).email,'synthetic@example.invalid');});
test('review rejects invalid ratings, short text, malformed contact and oversized fields',()=>{for(const patch of [{rating:0},{rating:6},{rating:2.4},{body:'short'},{name:''},{name:'x'.repeat(81)},{title:'x'.repeat(161)},{body:'x'.repeat(4001)},{email:'invalid'}])assert.throws(()=>validateReview({...valid,...patch}));});
test('review rejects executable markup, spam links and honeypot submissions',()=>{for(const patch of [{body:'<script>alert(1)</script>'},{body:'Buy this at https://example.invalid'},{website:'bot-filled'},{name:'<img onerror=bad>'},{body:'nul\u0000 test here'}])assert.throws(()=>validateReview({...valid,...patch}));});
