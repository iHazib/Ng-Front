import { assets } from '@/config/assets';
import { Icon } from './Icon';

const categories = ['Skincare', 'Makeup', 'Fragrances', 'Bath & Body', 'Cutlery'];

export function Header() {
  return <>
    <div className="announcement">Nook &amp; Glow · Beauty, home &amp; lifestyle</div>
    <header className="header ng-header">
      <div className="nav-intro">BEAUTY · HOME · EVERYDAY</div>
      <a href="#top" className="mark ng-logo" aria-label="Nook & Glow home"><img src={assets.brand.headerLogo} alt="Nook & Glow" /></a>
      <div className="tools">
        <button className="search-trigger" disabled title="Search is pending the visual stage"><Icon name="search" /><span>Discover</span></button>
        <button className="bag-button" disabled aria-label="Shopping bag preview, 0 items"><Icon name="bag" /><span className="bag-count">0</span></button>
      </div>
      <nav className="nav ng-links" aria-label="Main navigation">
        {categories.map((category) => <div className="nav-category" key={category}><button className="category-toggle" disabled title="Category navigation is pending the visual stage"><span>{category}</span><Icon name="chevron" /></button></div>)}
        <a href="#preview-note">Brands</a><a href="#preview-note">About Us</a><a href="#preview-note">Blogs</a>
      </nav>
    </header>
  </>;
}
