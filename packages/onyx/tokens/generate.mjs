#!/usr/bin/env node
// Onyx token generator: reads onyx.tokens.json and writes the two files the apps use.
//   node packages/onyx/tokens/generate.mjs        (from ~/auto_split; no dependencies)
//   -> packages/onyx/lib/src/tokens.g.dart        Dart constants for One Tracker
//   -> ../splitwise_mine/src/ui/tokens.g.css      CSS custom properties for One Split (skipped if that repo is not beside this one)
// Output is deterministic: same JSON in, same bytes out.
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const T = JSON.parse(readFileSync(resolve(here, 'onyx.tokens.json'), 'utf8'))
const dartOut = resolve(here, '../lib/src/tokens.g.dart')
const cssOut = process.env.ONYX_CSS_OUT ?? resolve(here, '../../../../splitwise_mine/src/ui/tokens.g.css')
const BANNER = 'GENERATED — edit onyx.tokens.json, run node packages/onyx/tokens/generate.mjs'

const MODES = ['light', 'dark']
const DEPTHS = ['strong', 'soft', 'surface', 'well']
const FINISHES = Object.keys(T.finish.recipes)
const COLOR_ROLES = Object.keys(T.color.light)

// ---------- shared helpers ----------
const num = (n) => String(Math.round(n * 1e4) / 1e4) // 0.1+0.2 noise out, trailing zeros off
const hexRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
const colorHex = (v) => (typeof v === 'string' ? v : v.color).toUpperCase()
const colorAlpha = (v) => (typeof v === 'string' ? 1 : v.alpha)
const recipe = (f, m, d) => T.finish.recipes[f]?.[m]?.[d] ?? {}
const hasBg = (f) => Boolean(T.finish.background[f])

// ---------- CSS ----------
const rgbOf = (base, mode) => {
  if (base === 'black') return [0, 0, 0]
  if (base === 'white') return [255, 255, 255]
  if (base === 'accent' || base === 'glow') return hexRgb(T.color[mode].accent) // glow: no fill to read in CSS
  return hexRgb(base)
}
const tint = ([base, a], mode) => `rgb(${rgbOf(base, mode).join(' ')} / ${num(a)})`
const stopColor = ([base, a], mode) => (a === 0 ? 'transparent' : tint([base, a], mode))
const px = (n) => (n === 0 ? '0' : `${num(n)}px`)

function gradient(sheen, stops, mode) {
  if (!sheen?.length) return 'none'
  const parts = sheen.map((t, i) => {
    const s = stops?.[i]
    return stopColor(t, mode) + (s ? ` ${num(s * 100)}%` : '')
  })
  return `linear-gradient(${parts.join(', ')})`
}

function boxShadow(r, mode) {
  const L = []
  if (r.highlight) L.push(`inset 0 1px 0 ${tint(r.highlight, mode)}`)
  if (r.rim) L.push(`inset 0 0 0 1px ${tint(r.rim, mode)}`)
  for (const [b, a, blur, dy, dx = 0] of r.insets ?? []) L.push(`inset ${px(dx)} ${px(dy)} ${px(blur)} ${tint([b, a], mode)}`)
  if (r.shade) L.push(`inset 0 -1px 0 ${tint(r.shade, mode)}`)
  for (const [b, a, blur, dy, dx = 0] of r.shadows ?? []) L.push(`${px(dx)} ${px(dy)} ${px(blur)} ${tint([b, a], mode)}`)
  return L.length ? L.join(', ') : '0 0 #0000'
}

const ref = T.finish.referenceWidth.px
function washCss(f, mode) {
  const ws = T.finish.background[f]?.[mode]
  if (!ws) return 'none'
  return ws
    .map((w) => {
      const c = w.color === 'accent' ? T.color[mode].accent : w.color
      const y = w.yOf === 'width' ? `${num(w.y * ref)}px` : `${num(w.y * 100)}%`
      return `radial-gradient(${num(w.radius * ref)}px circle at ${num(w.x * 100)}% ${y}, ${tint([c, w.alpha], mode)}, transparent)`
    })
    .join(', ')
}

const bezier = (c) => `cubic-bezier(${c.map(num).join(', ')})`

function finishVars(f, mode) {
  const strong = recipe(f, mode, 'strong')
  const soft = recipe(f, mode, 'soft')
  const surface = recipe(f, mode, 'surface')
  const well = recipe(f, mode, 'well')
  // In light mode the soft fill is a white surface: use the sheen meant for white fills.
  const softSheen = mode === 'light' && soft.sheenOnWhite ? soft.sheenOnWhite : soft.sheen
  const hair = T.finish.hairlines.finishes.includes(f)
  const v = []
  if (surface.fill === 'canvas') v.push(['--o-surface', 'var(--o-canvas)'])
  else if (surface.fillAlpha != null) v.push(['--o-surface', tint([T.color[mode].surface, surface.fillAlpha], mode)])
  if (well.fill === 'canvas') v.push(['--o-raised', 'var(--o-canvas)'])
  else if (well.fillAlpha != null) v.push(['--o-raised', tint([T.color[mode].raised, well.fillAlpha], mode)])
  v.push(['--f-hairline', hair ? '0 0 0 1px var(--o-line) inset' : '0 0 #0000'])
  v.push(['--f-edge', hair ? '0 0 0 1px var(--o-line-strong) inset' : '0 0 #0000'])
  v.push(['--f-blur', f === 'glass' ? `blur(${T.blur.tabBarSigma}px) saturate(${num(T.blur.cssSaturate)})` : 'none'])
  v.push(['--o-canvas-wash', washCss(f, mode)])
  v.push(['--f-strong-sheen', gradient(strong.sheen, strong.sheenStops, mode)])
  v.push(['--f-soft-sheen', gradient(softSheen, soft.sheenStops, mode)])
  v.push(['--f-surface-sheen', gradient(surface.sheen, surface.sheenStops, mode)])
  v.push(['--f-strong', boxShadow(strong, mode)])
  v.push(['--f-soft', boxShadow(soft, mode)])
  v.push(['--f-surface', boxShadow(surface, mode)])
  v.push(['--f-well', boxShadow(well, mode)])
  return v
}

const decl = (pairs, indent = '  ') => pairs.map(([k, v]) => `${indent}${k}: ${v};`).join('\n')

function genCss() {
  const kebab = (s) => s.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)
  const colorVars = (mode) => {
    const c = T.color[mode]
    const out = COLOR_ROLES.filter((r) => !['onAccent', 'scrim'].includes(r)).map((r) => [`--o-${kebab(r)}`, c[r].toLowerCase()])
    out.push(['--o-on-negative', c.onInk.toLowerCase()])
    out.push(['--o-scrim', tint([colorHex(c.scrim), colorAlpha(c.scrim)], mode)])
    out.push(['--f-floating', T.elevation.floating[mode].map(([b, a, blur, dy, dx = 0]) => `${px(dx)} ${px(dy)} ${px(blur)} ${tint([b, a], mode)}`).join(', ')])
    return out
  }
  // scrim colour is a hex, not a base name: tint() takes hex via rgbOf's fallthrough.
  const o = []
  o.push(`/* ${BANNER} */`)
  o.push(`/* Onyx tokens for One Split (same source as One Tracker's tokens.g.dart). Only the light/dark colours, the five finishes and the scales live here; One Split's own rules (balance mood, reduced effects) are in tokens.css. */`)

  // Scales: same in both modes.
  const scale = [['--o-font', T.type.cssFamily], ['--o-font-display', T.type.cssDisplayFamily]]
  for (const [k, v] of Object.entries(T.space)) if (k !== '$description') scale.push([`--o-space-${kebab(k)}`, px(v)])
  for (const [k, v] of Object.entries(T.radius)) if (k !== '$description') scale.push([`--o-radius-${kebab(k)}`, px(v)])
  for (const [k, v] of Object.entries(T.type.styles)) {
    const fam = v.display ? 'var(--o-font-display)' : 'var(--o-font)'
    scale.push([`--o-type-${kebab(k)}`, `${v.weight} ${v.size}px/${num(v.height)} ${fam}`])
    scale.push([`--o-type-${kebab(k)}-tracking`, v.tracking == null ? 'normal' : `${num(v.tracking)}px`])
  }
  for (const [k, v] of Object.entries(T.motion.duration)) scale.push([`--o-dur-${k}`, `${v}ms`])
  scale.push(['--o-ease', bezier(T.motion.easing.standard)], ['--o-ease-emph', bezier(T.motion.easing.emphasized)], ['--o-ease-exit', bezier(T.motion.easing.exit)])
  scale.push(['--o-blur-scrim', `${T.blur.scrimSigma}px`])
  o.push(`:root {\n${decl(scale)}\n}\n`)

  // Raised is the default look: it sits on the base selectors.
  const lightSel = (f) => (f === 'raised' ? ':root, :root :where([data-finish-preview])' : `:root[data-finish='${f}'], :root [data-finish-preview='${f}']`)
  const darkSel = (f) =>
    f === 'raised'
      ? ":root[data-mode='dark'], :root[data-mode='dark'] :where([data-finish-preview])"
      : `:root[data-finish='${f}'][data-mode='dark'], :root[data-mode='dark'] [data-finish-preview='${f}']`

  o.push(`/* Raised (the default): lit from above. Colours, then the finish. Depths: strong (solid buttons) › soft (light buttons) › surface (cards, bars) › well (fields, trays). */`)
  o.push(`${lightSel('raised')} {\n${decl([...colorVars('light'), ...finishVars('raised', 'light')])}\n}\n`)
  o.push(`${darkSel('raised')} {\n${decl([...colorVars('dark'), ...finishVars('raised', 'dark')])}\n}\n`)
  for (const f of FINISHES.filter((x) => x !== 'raised')) {
    o.push(`/* ${f[0].toUpperCase() + f.slice(1)}. Each finish sets both modes, so it wins over the plain dark block above. [data-finish-preview] is a Style tile showing that finish. */`)
    if (f === 'flat') {
      // Same in both modes: one rule.
      o.push(`:root[data-finish='flat'], :root[data-finish='flat'][data-mode='dark'], :root [data-finish-preview='flat'] {\n${decl(finishVars(f, 'light'))}\n}\n`)
      continue
    }
    o.push(`${lightSel(f)} {\n${decl(finishVars(f, 'light'))}\n}\n`)
    o.push(`${darkSel(f)} {\n${decl(finishVars(f, 'dark'))}\n}\n`)
  }
  return o.join('\n')
}

// ---------- Dart ----------
const dnum = (n) => (Number.isInteger(n) ? n.toFixed(1) : num(n))
const argb = (hex, alpha = 1) => `Color(0x${Math.round(alpha * 255).toString(16).toUpperCase().padStart(2, '0')}${hex.slice(1).toUpperCase()})`
const tintDart = ([b, a]) => `OTint(OTintBase.${b}, ${dnum(a)})`
const shadowDart = ([b, a, blur, dy, dx = 0]) => `OShadowToken(${tintDart([b, a])}, ${dnum(blur)}, ${dnum(dy)}${dx ? `, ${dnum(dx)}` : ''})`
const list = (xs, fn) => `[${xs.map(fn).join(', ')}]`
const boxShadowDart = ([b, a, blur, dy, dx = 0]) => {
  const c = argb(b === 'black' ? '#000000' : '#FFFFFF', a)
  return `BoxShadow(color: ${c}, blurRadius: ${dnum(blur)}, offset: Offset(${dnum(dx)}, ${dnum(dy)}))`
}

function recipeDart(r) {
  const f = []
  if (r.fill === 'canvas') f.push('fillCanvas: true')
  if (r.fillAlpha != null) f.push(`fillAlpha: ${dnum(r.fillAlpha)}`)
  if (r.sheen) f.push(`sheen: ${list(r.sheen, tintDart)}`)
  if (r.sheenOnWhite) f.push(`sheenOnWhite: ${list(r.sheenOnWhite, tintDart)}`)
  if (r.sheenStops) f.push(`sheenStops: ${list(r.sheenStops, dnum)}`)
  if (r.highlight) f.push(`highlight: ${tintDart(r.highlight)}`)
  if (r.shade) f.push(`shade: ${tintDart(r.shade)}`)
  if (r.rim) f.push(`rim: ${tintDart(r.rim)}`)
  if (r.shadows) f.push(`shadows: ${list(r.shadows, shadowDart)}`)
  if (r.insets) f.push(`insets: ${list(r.insets, shadowDart)}`)
  if (r.pressedShade) f.push(`pressedShade: ${tintDart(r.pressedShade)}`)
  return `ORecipeToken(${f.join(', ')})`
}

function genDart() {
  const o = []
  o.push(`// ${BANNER}`)
  o.push(`// ignore_for_file: type=lint`)
  o.push(`import 'package:flutter/widgets.dart';\n`)

  for (const m of MODES) {
    const c = T.color[m]
    o.push(`/// ${m} colour roles (OColors.${m}).`)
    o.push(`abstract final class OToken${m[0].toUpperCase() + m.slice(1)} {`)
    for (const r of COLOR_ROLES) o.push(`  static const ${r} = ${argb(colorHex(c[r]), colorAlpha(c[r]))};`)
    o.push(`}\n`)
  }

  o.push(`abstract final class OTokenSpace {`)
  for (const [k, v] of Object.entries(T.space)) if (k !== '$description') o.push(`  static const ${k} = ${dnum(v)};`)
  o.push(`}\n`)
  o.push(`abstract final class OTokenRadius {`)
  for (const [k, v] of Object.entries(T.radius)) if (k !== '$description') o.push(`  static const ${k} = ${dnum(v)};`)
  o.push(`}\n`)

  o.push(`abstract final class OTokenMotion {`)
  for (const [k, v] of Object.entries(T.motion.duration)) o.push(`  static const ${k} = Duration(milliseconds: ${v});`)
  for (const [k, v] of Object.entries(T.motion.easing)) o.push(`  static const ${k} = Cubic(${v.map(dnum).join(', ')});`)
  o.push(`}\n`)

  o.push(`abstract final class OTokenShadow {`)
  for (const k of ['floating', 'subtle'])
    for (const m of MODES) o.push(`  static const ${k}${m[0].toUpperCase() + m.slice(1)} = <BoxShadow>${list(T.elevation[k][m], boxShadowDart)};`)
  o.push(`  static const tabBarBlurSigma = ${dnum(T.blur.tabBarSigma)};`)
  o.push(`  static const scrimBlurSigma = ${dnum(T.blur.scrimSigma)};`)
  o.push(`}\n`)

  o.push(`/// Which colour a type style takes.`)
  o.push(`enum OTypeInk { ink, inkSoft }\n`)
  o.push(`/// One style of the type ramp. A null [tracking] leaves letter spacing alone.`)
  o.push(`class OTypeToken {`)
  o.push(`  const OTypeToken(this.size, this.weight, this.tracking, this.height, this.display, this.ink);`)
  o.push(`  final double size;\n  final FontWeight weight;\n  final double? tracking;\n  final double height;\n  final bool display;\n  final OTypeInk ink;\n}\n`)
  o.push(`abstract final class OTokenType {`)
  o.push(`  static const family = '${T.type.family}';`)
  o.push(`  static const displayFamily = '${T.type.displayFamily}';`)
  o.push(`  static const features = [${T.type.features.map((x) => `FontFeature('${x}')`).join(', ')}];`)
  for (const [k, v] of Object.entries(T.type.styles))
    o.push(`  static const ${k} = OTypeToken(${dnum(v.size)}, FontWeight.w${v.weight}, ${v.tracking == null ? 'null' : dnum(v.tracking)}, ${dnum(v.height)}, ${v.display}, OTypeInk.${v.color});`)
  o.push(`}\n`)

  o.push(`/// Tint bases: [glow] is the fill's own colour when it is saturated, else the accent.`)
  o.push(`enum OTintBase { black, white, accent, glow }\n`)
  o.push(`class OTint {\n  const OTint(this.base, this.alpha);\n  final OTintBase base;\n  final double alpha;\n}\n`)
  o.push(`/// [color] x [dx] y [dy] with a blur radius (CSS blur, so the sigma is half).`)
  o.push(`class OShadowToken {\n  const OShadowToken(this.tint, this.blur, this.dy, [this.dx = 0]);\n  final OTint tint;\n  final double blur;\n  final double dy;\n  final double dx;\n}\n`)
  o.push(`/// What a finish adds over a fill, at one depth and mode. See onyx.tokens.json.`)
  o.push(`class ORecipeToken {`)
  o.push(`  const ORecipeToken({\n    this.fillCanvas = false,\n    this.fillAlpha = 1,\n    this.sheen = const [],\n    this.sheenOnWhite,\n    this.sheenStops,\n    this.highlight,\n    this.shade,\n    this.rim,\n    this.shadows = const [],\n    this.insets = const [],\n    this.pressedShade,\n  });`)
  o.push(`  final bool fillCanvas;\n  final double fillAlpha;\n  final List<OTint> sheen;\n  final List<OTint>? sheenOnWhite;\n  final List<double>? sheenStops;\n  final OTint? highlight;\n  final OTint? shade;\n  final OTint? rim;\n  final List<OShadowToken> shadows;\n  final List<OShadowToken> insets;\n  final OTint? pressedShade;\n}\n`)
  o.push(`/// A radial wash behind the screen. [x] and [y] are fractions of the width and height ([yOfWidth]: y is a fraction of the width); a null [color] is the accent.`)
  o.push(`class OWashToken {\n  const OWashToken(this.x, this.y, this.yOfWidth, this.radius, this.color, this.alpha);\n  final double x;\n  final double y;\n  final bool yOfWidth;\n  final double radius;\n  final Color? color;\n  final double alpha;\n}\n`)

  o.push(`abstract final class OTokenFinish {`)
  o.push(`  static const hairlines = {${T.finish.hairlines.finishes.map((x) => `'${x}'`).join(', ')}};`)
  o.push(`  static const pressedShade = ${tintDart(T.finish.pressedShade)};`)
  o.push(`  /// Keyed '<finish>.<light|dark>.<depth>'.`)
  o.push(`  static const recipes = <String, ORecipeToken>{`)
  for (const f of FINISHES) for (const m of MODES) for (const d of DEPTHS) o.push(`    '${f}.${m}.${d}': ${recipeDart(recipe(f, m, d))},`)
  o.push(`  };`)
  o.push(`  /// Keyed '<finish>.<light|dark>'; only glass and glow have washes.`)
  o.push(`  static const washes = <String, List<OWashToken>>{`)
  for (const f of FINISHES.filter(hasBg))
    for (const m of MODES) {
      const ws = T.finish.background[f][m].map((w) => `OWashToken(${dnum(w.x)}, ${dnum(w.y)}, ${w.yOf === 'width'}, ${dnum(w.radius)}, ${w.color === 'accent' ? 'null' : argb(w.color)}, ${dnum(w.alpha)})`)
      o.push(`    '${f}.${m}': [${ws.join(', ')}],`)
    }
  o.push(`  };`)
  o.push(`}`)
  return o.join('\n') + '\n'
}

// ---------- write ----------
writeFileSync(dartOut, genDart())
console.log(`wrote ${dartOut}`)
if (existsSync(dirname(cssOut))) {
  writeFileSync(cssOut, genCss())
  console.log(`wrote ${cssOut}`)
} else console.log(`skipped CSS: ${dirname(cssOut)} not found (set ONYX_CSS_OUT)`)
