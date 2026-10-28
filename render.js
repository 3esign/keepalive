// KEEPALIVE — JS mirror of the on-chain Solidity renderer (Keepalive.sol).
// Same seed math, same palette, same flame. Used by the site preview and
// as the visual reference for the contract's SVG output.

function keccakF(bytes) {} // in browser we substitute with a simple PRNG seeded identically for preview;
// on-chain truth is always the contract — this is the looking glass, not the source.

// deterministic PRNG (xmur3 + mulberry32) — good enough to preview composition
function prng(seedStr) {
  let h = 1779033703 ^ seedStr.length;
  for (let i = 0; i < seedStr.length; i++) {
    h = Math.imul(h ^ seedStr.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = (h ^= h >>> 16) >>> 0;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const u2s = (v) => String(v);
const i2s = (v) => String(v);
const hsl = (h, s, l) => `hsl(${h} ${s}% ${l}%)`;

export function render({ tokenId, seed, level, ash, keeper }) {
  const R = prng(`${tokenId}:${seed}`);
  const hue = Math.floor(R() * 360);
  const hue2 = (hue + 28) % 360;
  const hue3 = (hue + 335) % 360;
  const bg = ash ? "#111112" : hsl(hue, 30, 5);
  const core = ash ? "#6b6b70" : hsl(hue, 95, 62);
  const mid = ash ? "#4c4c52" : hsl(hue2, 90, 52);
  const edge = ash ? "#333338" : hsl(hue3, 85, 42);
  const lvl = Math.min(level, 12);
  const flameH = 140 + lvl * 9;
  const flameW = 90 + Math.floor(R() * 30) + Math.min(level, 10) * 2;

  const tilt = (i) => Math.floor(R() * 36) - 18;
  let flame = "";
  for (let i = 0; i < 3; i++) {
    const f = 100 - i * 28;
    const ww = (flameW * f) / 100, hh = (flameH * f) / 100;
    const col = i === 0 ? core : i === 1 ? mid : edge;
    const t = tilt(i);
    flame += `<path transform="translate(300 430) rotate(${t})" d="M 0 0 C ${ww / 2} ${-hh / 4}, ${ww / 3} ${-hh}, 0 ${-hh} C ${-ww / 3} ${-hh}, ${-ww / 2} ${-hh / 4}, 0 0 Z" fill="${col}" opacity="0.85"/>`;
  }
  const heartR = 10 + Math.floor(R() * 8);
  flame += `<circle cx="300" cy="422" r="${heartR}" fill="${ash ? "#8a8a90" : "#fff8e8"}" opacity="${ash ? 0.4 : 0.95}"/>`;

  let sparks = "";
  if (!ash) {
    const n = 8 + Math.min(level, 10);
    for (let i = 0; i < n; i++) {
      sparks += `<circle cx="${90 + Math.floor(R() * 230)}" cy="${430 - Math.floor(R() * 260)}" r="${2 + Math.floor(R() * 4)}" fill="${i % 2 === 0 ? hsl(hue, 95, 70) : hsl(hue2, 90, 60)}" opacity="0.7"/>`;
    }
  } else {
    for (let i = 0; i < 14; i++) {
      sparks += `<circle cx="${140 + Math.floor(R() * 320)}" cy="${400 + Math.floor(R() * 140)}" r="${1 + Math.floor(R() * 2)}" fill="${edge}" opacity="0.6"/>`;
    }
  }

  const bars = "|".repeat(Math.min(level, 14));
  const head = ash ? "ASH — WAITING" : `breathe ${level} ${bars}`;
  const kept = keeper ? `<text x="300" y="68" font-family="monospace" font-size="10" fill="${mid}" text-anchor="middle">kept by ${keeper}</text>` : "";

  return `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">
<defs><radialGradient id="g" cx="50%" cy="72%" r="65%">
<stop offset="0%" stop-color="${mid}" stop-opacity="0.9"/>
<stop offset="55%" stop-color="${bg}"/><stop offset="100%" stop-color="${bg}"/>
</radialGradient></defs>
<rect width="600" height="600" fill="url(#g)"/>
<rect x="10" y="10" width="580" height="580" fill="none" stroke="${edge}" stroke-width="1.5"/>
${flame}${sparks}
<text x="300" y="566" font-family="monospace" font-size="15" fill="${mid}" text-anchor="middle">KEEPALIVE #${tokenId}</text>
<text x="300" y="50" font-family="monospace" font-size="11" fill="${edge}" text-anchor="middle">${head}</text>
${kept}
</svg>`;
}
