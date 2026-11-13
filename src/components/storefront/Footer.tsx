import { assets } from '@/config/assets';
import { site } from '@/config/site';
import { Icon } from './Icon';

export function Footer() {
  return <footer className="footer premium-footer refined-footer" id="footer">
    <div className="footer-opening"><span className="eyebrow">A considered world of beauty &amp; home</span><a href="#top" className="footer-top-link" aria-label="Back to top"><span>Back to top</span><b aria-hidden="true">↑</b></a></div>
    <div className="footer-top">
      <div className="footer-brand"><img src={assets.brand.logo} alt="Nook & Glow" loading="lazy" /><p>Make room for<br /><em>the little things.</em></p><span>Beauty, home and everyday discoveries.<br />Thoughtfully brought together.</span></div>
      <div className="footer-follow">
        <div className="footer-contact"><span className="eyebrow">Let’s talk</span><a className="contact-email" href={`mailto:${site.contactEmail}`}>{site.contactEmail} <span aria-hidden="true">↗</span></a><p>For product questions and a little guidance.</p></div>
        <p className="eyebrow">Follow us</p><h3>Stay close to the edit.</h3><p>Beauty, inspiration and the latest from our edit.</p>
        <div className="social-row">{(['instagram', 'facebook'] as const).map((name) => <button key={name} className="social-link" disabled title="Social profile URL is awaiting approval"><Icon name={name} /><span>{name === 'instagram' ? 'Instagram' : 'Facebook'}</span>↗</button>)}</div>
      </div>
    </div>
    <nav className="footer-sitemap" aria-label="Footer sitemap">
      <div><h4>Shop collections</h4>{['Skincare', 'Makeup', 'Fragrances', 'Bath & Body', 'Cutlery'].map((name) => <a key={name} href="#preview-note">{name}</a>)}</div>
      <div><h4>Discover</h4>{['Shop by concern', 'Shop by brand', 'The Edit', 'Our story'].map((name) => <a key={name} href="#preview-note">{name}</a>)}</div>
      <div><h4>Customer care</h4><a className="footer-link" href={`mailto:${site.contactEmail}`}>Contact us</a>{['Delivery & tracking', 'Returns & refunds', 'FAQs'].map((name) => <button key={name} className="footer-link" disabled>{name}</button>)}</div>
      <div><h4>The details</h4>{['Privacy policy', 'Terms & conditions', 'Shipping policy'].map((name) => <button key={name} className="footer-link" disabled>{name}</button>)}<a href="#footer">Sitemap</a></div>
    </nav>
    <div className="footer-signature" aria-hidden="true">Nook <i>&amp;</i> Glow<span>Beauty in every corner.</span></div>
    <div className="footer-bottom"><span>© Nook &amp; Glow · All rights reserved</span><a href="#top" className="back-top">Back to top ↑</a><span>Beauty · Home · Lifestyle</span></div>
  </footer>;
}
