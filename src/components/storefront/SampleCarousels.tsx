'use client';

import { useEffect, useRef, useState, type FocusEvent, type KeyboardEvent, type PointerEvent, type RefObject } from 'react';
import { assign, byClass, byId, Node, Plain, type MarkupNode, type Overrides } from './SampleMarkup';

function usePlayback(root: RefObject<HTMLElement | null>) {
  const [reduced, setReduced] = useState(true);
  const [visible, setVisible] = useState(false);
  const [awake, setAwake] = useState(true);
  useEffect(() => {
    const motion = matchMedia('(prefers-reduced-motion: reduce)');
    const updateMotion = () => setReduced(motion.matches);
    const updateAwake = () => setAwake(!document.hidden);
    updateMotion(); updateAwake();
    motion.addEventListener('change', updateMotion);
    document.addEventListener('visibilitychange', updateAwake);
    const observer = new IntersectionObserver(entries => setVisible(entries[0].isIntersecting));
    if (root.current) observer.observe(root.current);
    return () => { observer.disconnect(); motion.removeEventListener('change', updateMotion); document.removeEventListener('visibilitychange', updateAwake); };
  }, [root]);
  return { reduced, visible, awake };
}
const wrap = (index: number, length: number) => (index + length) % length;
const exitFocus = (event: FocusEvent) => !event.currentTarget.contains(event.relatedTarget);
function useSwipe(move: (direction: number) => void, threshold: number) {
  const point = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  return {
    onPointerDown: (event: PointerEvent<HTMLElement>) => {
      if (event.button > 0 || (event.target as HTMLElement).closest('button')) return;
      point.current = { x: event.clientX, y: event.clientY, moved: false };
    },
    onPointerMove: (event: PointerEvent<HTMLElement>) => {
      if (point.current && Math.abs(event.clientX - point.current.x) > 10) {
        point.current.moved = true;
        event.currentTarget.setPointerCapture(event.pointerId);
      }
    },
    onPointerUp: (event: PointerEvent) => {
      const start = point.current;
      if (!start) return;
      const dx = event.clientX - start.x, dy = event.clientY - start.y;
      if (Math.abs(dx) > threshold && Math.abs(dx) > Math.abs(dy)) move(dx < 0 ? 1 : -1);
      if (!start.moved) point.current = null;
    },
    onPointerCancel: () => { point.current = null; },
    onClickCapture: (event: React.MouseEvent) => { if (point.current?.moved) { event.preventDefault(); event.stopPropagation(); } point.current = null; },
    onDragStart: (event: React.DragEvent) => event.preventDefault(),
  };
}

export function Carousel({ node, kind }: { node: MarkupNode; kind: 'hero' | 'edit' | 'gallery' }) {
  const root = useRef<HTMLElement>(null);
  const { reduced, visible, awake } = usePlayback(root);
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const [hover, setHover] = useState(false);
  const [focus, setFocus] = useState(false);
  const slides = byClass(node, kind === 'gallery' ? 'product-slide' : `${kind}-slide`);
  const dots = byClass(node, `${kind}-dot`);
  const move = (direction: number) => {if(slides.length>1)setIndex(current => wrap(current + direction, slides.length));};
  const swipe = useSwipe(move, 55);
  const active = kind === 'gallery' ? hover || focus : !hover && !focus && !paused;
  useEffect(() => {
    if (slides.length<2 || reduced || !awake || (kind !== 'hero' && !visible) || !active) return;
    const timer = setInterval(() => setIndex(current => wrap(current + 1, slides.length)), kind === 'hero' ? 7600 : kind === 'edit' ? 8000 : 2500);
    return () => clearInterval(timer);
  }, [reduced, awake, visible, active, kind, slides.length, index]);
  const map: Overrides = new Map();
  const editTheme=node.attrs['data-content-cms']?slides[index]?.attrs['data-theme']:index===1?'warm':index===2?'blush':'sage';
  assign(map, node, {
    ref: root,
    className: `${node.attrs.class}${kind === 'hero' && (index === 1 || index === 3) ? ' is-dark' : ''}${kind === 'edit' && editTheme === 'warm' ? ' is-warm' : ''}${kind === 'edit' && editTheme === 'blush' ? ' is-blush' : ''}`,
    onMouseEnter: () => { setHover(true); if (kind === 'gallery' && !reduced && slides.length>1) setIndex(1); },
    onMouseLeave: () => setHover(false),
    onFocus: () => setFocus(true),
    onBlur: (event: FocusEvent) => { if (exitFocus(event)) setFocus(false); },
    onKeyDown: (event: KeyboardEvent) => { if (['ArrowLeft', 'ArrowRight'].includes(event.key)) { event.preventDefault(); move(event.key === 'ArrowRight' ? 1 : -1); } },
    ...(kind === 'edit' ? swipe : {}),
  });
  slides.forEach((slide, i) => assign(map, slide, { className: slide.attrs.class.replace(/\s*\bactive\b/, '') + (i === index ? ' active' : ''), ...(kind !== 'gallery' ? { inert: i !== index, 'aria-hidden': i !== index } : {}) }));
  dots.forEach((dot, i) => assign(map, dot, { className: `${kind}-dot${i === index ? ' active' : ''}`, [kind === 'hero' ? 'aria-selected' : 'aria-pressed']: i === index, onClick: () => setIndex(i) }));
  assign(map, byId(node, `${kind}-prev`) || byClass(node, `${kind}-prev`)[0], { onClick: () => move(-1) });
  assign(map, byId(node, `${kind}-next`) || byClass(node, `${kind}-next`)[0], { onClick: () => move(1) });
  assign(map, byId(node, `${kind}-pause`), { children: paused ? '▶' : 'Ⅱ', 'aria-pressed': paused, 'aria-label': `${paused ? 'Play' : 'Pause'} ${kind === 'hero' ? 'slideshow' : 'article slideshow'}`, onClick: () => setPaused(!paused) });
  if (kind === 'edit') assign(map, byClass(node, 'edit-position')[0], { children: `${String(index+1).padStart(2,'0')} / ${String(slides.length).padStart(2,'0')}` });
  return <Plain node={node} overrides={map} />;
}

export function CategoryCarousel({ node }: { node: MarkupNode }) {
  const root = useRef<HTMLElement>(null);
  const shell = useRef<HTMLDivElement>(null);
  const { reduced, visible, awake } = usePlayback(root);
  const [index, setIndex] = useState(0);
  const [step, setStep] = useState(210);
  const [paused, setPaused] = useState(false);
  const [hover, setHover] = useState(false);
  const [focus, setFocus] = useState(false);
  const cards = byClass(node, 'corner-card');
  const move = (direction: number) => setIndex(current => wrap(current + direction, cards.length));
  const swipe = useSwipe(move, 35);
  useEffect(() => {
    const resize = () => setStep(Math.min((shell.current?.clientWidth ?? 1106) * .19, 210));
    resize(); window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, []);
  useEffect(() => {
    if (reduced || !awake || !visible || paused || hover || focus) return;
    const timer = setInterval(() => setIndex(current => wrap(current + 1, cards.length)), 6500);
    return () => clearInterval(timer);
  }, [reduced, awake, visible, paused, hover, focus, cards.length, index]);
  const map: Overrides = new Map();
  assign(map, node, { ref: root, onMouseEnter: () => setHover(true), onMouseLeave: () => setHover(false), onFocus: () => setFocus(true), onBlur: (event: FocusEvent) => { if (exitFocus(event)) setFocus(false); } });
  assign(map, byClass(node, 'corner-shell')[0], { ref: shell, ...swipe, onKeyDown: (event: KeyboardEvent) => { if (['ArrowLeft', 'ArrowRight'].includes(event.key)) { event.preventDefault(); move(event.key === 'ArrowRight' ? 1 : -1); } } });
  cards.forEach((card, i) => {
    let distance = wrap(i - index, cards.length); if (distance > 2) distance -= 5;
    const abs = Math.abs(distance);
    assign(map, card, { className: `corner-card${distance === 0 ? ' active' : ''}`, style: { transform: `translateX(calc(-50% + ${distance * step}px)) translateY(${abs * 13}px) rotate(${distance * 4}deg) scale(${abs === 0 ? 1 : abs === 1 ? .86 : .72})`, zIndex: 5 - abs, filter: distance ? 'brightness(.88)' : 'none' } });
  });
  byClass(node, 'corner-dot').forEach((dot, i) => assign(map, dot, { className: `corner-dot${i === index ? ' active' : ''}`, 'aria-pressed': i === index, onClick: () => setIndex(i) }));
  assign(map, byClass(node, 'corner-prev')[0], { onClick: () => move(-1) });
  assign(map, byClass(node, 'corner-next')[0], { onClick: () => move(1) });
  assign(map, byId(node, 'corner-description'), { children: cards[index].attrs['data-description'] });
  assign(map, byClass(node, 'corner-pause')[0], { children: paused ? '▶' : 'Ⅱ', 'aria-pressed': paused, 'aria-label': `${paused ? 'Play' : 'Pause'} category carousel`, onClick: () => setPaused(!paused) });
  return <Plain node={node} overrides={map} />;
}

export function ScrollRail({ node, kind }: { node: MarkupNode; kind: 'brands' | 'concerns' }) {
  const root = useRef<HTMLElement>(null);
  const viewport = useRef<HTMLDivElement>(null);
  const track = useRef<HTMLDivElement>(null);
  const { reduced, visible, awake } = usePlayback(root);
  const [edges, setEdges] = useState({ start: true, end: false });
  const [dragging, setDragging] = useState(false);
  const drag = useRef({ down: false, x: 0, left: 0, moved: false });
  const pauseUntil = useRef(0);
  const normalize = () => {
    const row = viewport.current;
    if (!row || kind !== 'brands') return;
    const segment = (track.current?.scrollWidth ?? 0) / 3;
    if (row.scrollLeft < segment * .5) row.scrollLeft += segment;
    else if (row.scrollLeft > segment * 1.5) row.scrollLeft -= segment;
  };
  const arrows = () => {
    const row = viewport.current;
    if (row && kind === 'concerns') setEdges({ start: row.scrollLeft < 2, end: row.scrollLeft + row.clientWidth >= row.scrollWidth - 2 });
  };
  useEffect(() => {
    const row = viewport.current;
    if (row && kind === 'brands') row.scrollLeft = (track.current?.scrollWidth ?? 0) / 3;
    const resize = () => { if (row && kind === 'concerns') setEdges({ start: row.scrollLeft < 2, end: row.scrollLeft + row.clientWidth >= row.scrollWidth - 2 }); };
    resize(); window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, [kind]);
  useEffect(() => {
    if (kind !== 'brands' || reduced || !visible || !awake) return;
    let frame = 0, previous = 0;
    const tick = (now: number) => {
      const row = viewport.current;
      const delta = Math.min(now - (previous || now), 50); previous = now;
      if (row && !drag.current.down && now > pauseUntil.current) {
        row.scrollLeft += delta * .017;
        const segment = (track.current?.scrollWidth ?? 0) / 3;
        if (row.scrollLeft > segment * 1.5) row.scrollLeft -= segment;
      }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [kind, reduced, visible, awake]);
  const scroll = (direction: number) => {
    const row = viewport.current; if (!row) return;
    pauseUntil.current = performance.now() + 2200;
    const card = row.querySelector('.concern-card');
    const step = kind === 'brands' ? 234 : (card?.getBoundingClientRect().width ?? 200) + parseFloat(getComputedStyle(row).gap);
    row.scrollBy({ left: direction * step, behavior: reduced ? 'instant' : 'smooth' });
  };
  const map: Overrides = new Map();
  assign(map, node, { ref: root });
  const rowNode = byClass(node, kind === 'brands' ? 'brand-viewport' : 'concerns-grid')[0];
  assign(map, rowNode, {
    ref: viewport, className: `${rowNode.attrs.class}${dragging ? ' dragging' : ''}`,
    onScroll: () => { normalize(); arrows(); },
    onPointerDown: (event: PointerEvent<HTMLDivElement>) => { if (event.button > 0) return; drag.current = { down: true, x: event.clientX, left: event.currentTarget.scrollLeft, moved: false }; pauseUntil.current = performance.now() + 3000; },
    onPointerMove: (event: PointerEvent<HTMLDivElement>) => {
      if (!drag.current.down) return;
      const delta = event.clientX - drag.current.x;
      if (Math.abs(delta) > 5) { drag.current.moved = true; setDragging(true); event.currentTarget.setPointerCapture(event.pointerId); event.currentTarget.scrollLeft = drag.current.left - delta; }
    },
    onPointerUp: () => { drag.current.down = false; setDragging(false); pauseUntil.current = performance.now() + 2000; },
    onPointerCancel: () => { drag.current.down = false; setDragging(false); },
    onClickCapture: (event: React.MouseEvent) => { if (drag.current.moved) { event.preventDefault(); event.stopPropagation(); drag.current.moved = false; } },
    onDragStart: (event: React.DragEvent) => event.preventDefault(),
    onMouseEnter: () => { pauseUntil.current = performance.now() + 100000; },
    onMouseLeave: () => { pauseUntil.current = performance.now() + 2200; },
    onFocus: () => { pauseUntil.current = performance.now() + 100000; },
    onBlur: () => { pauseUntil.current = performance.now() + 2200; },
    onKeyDown: (event: KeyboardEvent) => { if (['ArrowLeft', 'ArrowRight'].includes(event.key)) { event.preventDefault(); scroll(event.key === 'ArrowRight' ? 1 : -1); } },
  });
  if (kind === 'brands') {
    const trackNode = byClass(node, 'brand-track')[0];
    const cards = byClass(node, 'brand-card');
    const clone = (card: MarkupNode): MarkupNode => ({ ...card, attrs: { ...card.attrs, 'aria-hidden': 'true', tabindex: '-1' } });
    assign(map, trackNode, { ref: track, children: [...cards.map(clone), ...cards, ...cards.map(clone)].map((card, i) => <Node key={i} node={card} />) });
    const buttons = byClass(node, 'brand-arrow');
    buttons.forEach((button, i) => assign(map, button, { onClick: () => scroll(i === 0 ? -1 : 1) }));
  } else {
    assign(map, byId(node, 'concerns-prev'), { disabled: edges.start, onClick: () => scroll(-1) });
    assign(map, byId(node, 'concerns-next'), { disabled: edges.end, onClick: () => scroll(1) });
  }
  return <Plain node={node} overrides={map} />;
}
