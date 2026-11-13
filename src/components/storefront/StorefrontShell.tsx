import { Header } from './Header';
import { Footer } from './Footer';
import './tokens.css';
import './reference.css';

export function StorefrontShell({ children }: { children: React.ReactNode }) {
  return <div className="storefront"><div className="site"><Header /><main id="top">{children}</main><Footer /></div></div>;
}
