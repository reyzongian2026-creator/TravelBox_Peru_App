/**
 * SVG Path → Flutter Canvas Path converter.
 *
 * Parses SVG path `d` attributes (M, L, C, Q, Z, H, V + lowercase relatives)
 * and outputs normalized Flutter Path() code.
 * 
 * Input: SVG path string + viewBox dimensions
 * Output: Flutter Dart moveTo/lineTo/cubicTo/quadraticBezierTo calls
 *         with coordinates normalized to [0..1] range.
 */

// ── SVG Path Parser ──

function parseSVGPath(d) {
  const commands = [];
  // Tokenize: split into command letters and numbers
  const tokens = d.match(/[a-zA-Z]|[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/g);
  if (!tokens) return commands;

  let i = 0;
  let currentCmd = '';

  function nextNum() {
    if (i >= tokens.length) return 0;
    return parseFloat(tokens[i++]);
  }

  while (i < tokens.length) {
    const t = tokens[i];
    if (/[a-zA-Z]/.test(t)) {
      currentCmd = t;
      i++;
    }

    switch (currentCmd) {
      case 'M':
        commands.push({ type: 'M', x: nextNum(), y: nextNum() });
        currentCmd = 'L'; // implicit lineTo after moveTo
        break;
      case 'm':
        commands.push({ type: 'm', dx: nextNum(), dy: nextNum() });
        currentCmd = 'l';
        break;
      case 'L':
        commands.push({ type: 'L', x: nextNum(), y: nextNum() });
        break;
      case 'l':
        commands.push({ type: 'l', dx: nextNum(), dy: nextNum() });
        break;
      case 'H':
        commands.push({ type: 'H', x: nextNum() });
        break;
      case 'h':
        commands.push({ type: 'h', dx: nextNum() });
        break;
      case 'V':
        commands.push({ type: 'V', y: nextNum() });
        break;
      case 'v':
        commands.push({ type: 'v', dy: nextNum() });
        break;
      case 'C':
        commands.push({
          type: 'C',
          x1: nextNum(), y1: nextNum(),
          x2: nextNum(), y2: nextNum(),
          x:  nextNum(), y:  nextNum()
        });
        break;
      case 'c':
        commands.push({
          type: 'c',
          dx1: nextNum(), dy1: nextNum(),
          dx2: nextNum(), dy2: nextNum(),
          dx:  nextNum(), dy:  nextNum()
        });
        break;
      case 'Q':
        commands.push({
          type: 'Q',
          x1: nextNum(), y1: nextNum(),
          x:  nextNum(), y:  nextNum()
        });
        break;
      case 'q':
        commands.push({
          type: 'q',
          dx1: nextNum(), dy1: nextNum(),
          dx:  nextNum(), dy:  nextNum()
        });
        break;
      case 'S':
        commands.push({
          type: 'S',
          x2: nextNum(), y2: nextNum(),
          x:  nextNum(), y:  nextNum()
        });
        break;
      case 's':
        commands.push({
          type: 's',
          dx2: nextNum(), dy2: nextNum(),
          dx:  nextNum(), dy:  nextNum()
        });
        break;
      case 'A':
        commands.push({
          type: 'A',
          rx: nextNum(), ry: nextNum(),
          rotation: nextNum(),
          largeArc: nextNum(),
          sweep: nextNum(),
          x: nextNum(), y: nextNum()
        });
        break;
      case 'a':
        commands.push({
          type: 'a',
          rx: nextNum(), ry: nextNum(),
          rotation: nextNum(),
          largeArc: nextNum(),
          sweep: nextNum(),
          dx: nextNum(), dy: nextNum()
        });
        break;
      case 'Z':
      case 'z':
        commands.push({ type: 'Z' });
        break;
      default:
        i++; // skip unknown
    }
  }
  return commands;
}

// Convert parsed commands to absolute coordinates
function toAbsolute(commands) {
  const result = [];
  let cx = 0, cy = 0; // current point
  let sx = 0, sy = 0; // start of subpath
  let prevX2, prevY2; // for smooth curves

  for (const cmd of commands) {
    switch (cmd.type) {
      case 'M':
        cx = cmd.x; cy = cmd.y;
        sx = cx; sy = cy;
        result.push({ type: 'M', x: cx, y: cy });
        break;
      case 'm':
        cx += cmd.dx; cy += cmd.dy;
        sx = cx; sy = cy;
        result.push({ type: 'M', x: cx, y: cy });
        break;
      case 'L':
        cx = cmd.x; cy = cmd.y;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'l':
        cx += cmd.dx; cy += cmd.dy;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'H':
        cx = cmd.x;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'h':
        cx += cmd.dx;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'V':
        cy = cmd.y;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'v':
        cy += cmd.dy;
        result.push({ type: 'L', x: cx, y: cy });
        break;
      case 'C':
        prevX2 = cmd.x2; prevY2 = cmd.y2;
        result.push({ type: 'C', x1: cmd.x1, y1: cmd.y1, x2: cmd.x2, y2: cmd.y2, x: cmd.x, y: cmd.y });
        cx = cmd.x; cy = cmd.y;
        break;
      case 'c':
        const cx1 = cx + cmd.dx1, cy1 = cy + cmd.dy1;
        const cx2 = cx + cmd.dx2, cy2 = cy + cmd.dy2;
        const cex = cx + cmd.dx, cey = cy + cmd.dy;
        prevX2 = cx2; prevY2 = cy2;
        result.push({ type: 'C', x1: cx1, y1: cy1, x2: cx2, y2: cy2, x: cex, y: cey });
        cx = cex; cy = cey;
        break;
      case 'S':
        const sx1 = prevX2 !== undefined ? 2*cx - prevX2 : cx;
        const sy1 = prevY2 !== undefined ? 2*cy - prevY2 : cy;
        prevX2 = cmd.x2; prevY2 = cmd.y2;
        result.push({ type: 'C', x1: sx1, y1: sy1, x2: cmd.x2, y2: cmd.y2, x: cmd.x, y: cmd.y });
        cx = cmd.x; cy = cmd.y;
        break;
      case 's':
        const ssx1 = prevX2 !== undefined ? 2*cx - prevX2 : cx;
        const ssy1 = prevY2 !== undefined ? 2*cy - prevY2 : cy;
        const ssx2 = cx + cmd.dx2, ssy2 = cy + cmd.dy2;
        const ssex = cx + cmd.dx, ssey = cy + cmd.dy;
        prevX2 = ssx2; prevY2 = ssy2;
        result.push({ type: 'C', x1: ssx1, y1: ssy1, x2: ssx2, y2: ssy2, x: ssex, y: ssey });
        cx = ssex; cy = ssey;
        break;
      case 'Q':
        result.push({ type: 'Q', x1: cmd.x1, y1: cmd.y1, x: cmd.x, y: cmd.y });
        cx = cmd.x; cy = cmd.y;
        break;
      case 'q':
        result.push({ type: 'Q', x1: cx + cmd.dx1, y1: cy + cmd.dy1, x: cx + cmd.dx, y: cy + cmd.dy });
        cx += cmd.dx; cy += cmd.dy;
        break;
      case 'Z':
        result.push({ type: 'Z' });
        cx = sx; cy = sy;
        break;
    }
  }
  return result;
}

// Generate Flutter Dart code from absolute commands, normalized to [0,1]
function toFlutter(absCommands, viewBoxW, viewBoxH, varPrefix = '') {
  const lines = [];
  const n = (v, dim) => {
    const norm = dim === 'x' ? v / viewBoxW : v / viewBoxH;
    return norm.toFixed(4);
  };

  for (const cmd of absCommands) {
    switch (cmd.type) {
      case 'M':
        lines.push(`  ..moveTo(${varPrefix}${n(cmd.x,'x')}, ${varPrefix}${n(cmd.y,'y')})`);
        break;
      case 'L':
        lines.push(`  ..lineTo(${varPrefix}${n(cmd.x,'x')}, ${varPrefix}${n(cmd.y,'y')})`);
        break;
      case 'C':
        lines.push(`  ..cubicTo(${varPrefix}${n(cmd.x1,'x')}, ${varPrefix}${n(cmd.y1,'y')}, ${varPrefix}${n(cmd.x2,'x')}, ${varPrefix}${n(cmd.y2,'y')}, ${varPrefix}${n(cmd.x,'x')}, ${varPrefix}${n(cmd.y,'y')})`);
        break;
      case 'Q':
        lines.push(`  ..quadraticBezierTo(${varPrefix}${n(cmd.x1,'x')}, ${varPrefix}${n(cmd.y1,'y')}, ${varPrefix}${n(cmd.x,'x')}, ${varPrefix}${n(cmd.y,'y')})`);
        break;
      case 'Z':
        lines.push(`  ..close()`);
        break;
    }
  }
  return lines.join('\n');
}

// ── Process MDI SVGs ──
console.log('='.repeat(60));
console.log('MDI AIRPLANE (viewBox 0 0 24 24)');
console.log('='.repeat(60));
const airplaneSvg = "M20.56 3.91C21.15 4.5 21.15 5.45 20.56 6.03L16.67 9.92L18.79 19.11L17.38 20.53L13.5 13.1L9.6 17L9.96 19.47L8.89 20.53L7.13 17.35L3.94 15.58L5 14.5L7.5 14.87L11.37 11L3.94 7.09L5.36 5.68L14.55 7.8L18.44 3.91C19 3.33 20 3.33 20.56 3.91Z";
const airplaneAbs = toAbsolute(parseSVGPath(airplaneSvg));
console.log('final airplane = Path()');
console.log(toFlutter(airplaneAbs, 24, 24) + ';');

console.log('\n' + '='.repeat(60));
console.log('MDI BIRD/CONDOR (viewBox 0 0 24 24)');
console.log('='.repeat(60));
const birdSvg = "M23 11.5L19.95 10.37C19.69 9.22 19.04 8.56 19.04 8.56C17.4 6.92 14.75 6.92 13.11 8.56L11.63 10.04L5 3C4 7 5 11 7.45 14.22L2 19.5C2 19.5 10.89 21.5 16.07 17.45C18.83 15.29 19.45 14.03 19.84 12.7L23 11.5M17.71 11.72C17.32 12.11 16.68 12.11 16.29 11.72C15.9 11.33 15.9 10.7 16.29 10.31C16.68 9.92 17.32 9.92 17.71 10.31C18.1 10.7 18.1 11.33 17.71 11.72Z";
const birdAbs = toAbsolute(parseSVGPath(birdSvg));
console.log('final condor = Path()');
console.log(toFlutter(birdAbs, 24, 24) + ';');

console.log('\n' + '='.repeat(60));
console.log('MDI PYRAMID (viewBox 0 0 24 24)');
console.log('='.repeat(60));
const pyramidSvg = "M21.85 16.96H21.85L12.85 2.47C12.65 2.16 12.33 2 12 2S11.35 2.16 11.15 2.47L2.15 16.96H2.15C1.84 17.45 2 18.18 2.64 18.43L11.64 21.93C11.75 22 11.88 22 12 22S12.25 22 12.36 21.93L21.36 18.43C22 18.18 22.16 17.45 21.85 16.96M11 6.5V13.32L5.42 15.5L11 6.5M12 19.93L5.76 17.5L12 15.07L18.24 17.5L12 19.93M13 13.32V6.5L18.58 15.5L13 13.32Z";
const pyramidAbs = toAbsolute(parseSVGPath(pyramidSvg));
console.log('final pyramid = Path()');
console.log(toFlutter(pyramidAbs, 24, 24) + ';');

console.log('\n' + '='.repeat(60));
console.log('MDI SUN-COMPASS / INTI (viewBox 0 0 24 24)');
console.log('='.repeat(60));
const sunSvg = "M9.7 4.3L12 1L14.3 4.3C13.6 4.1 12.8 4 12 4S10.4 4.1 9.7 4.3M17.5 6.2C18.6 7.3 19.5 8.7 19.8 10.3L21.5 6.6L17.5 6.2M5 8.1C5.1 8 5.1 8 5 8.1C5.1 8 5.1 8 5.1 7.9C5.5 7.3 6 6.7 6.5 6.2L2.5 6.5L4.2 10.2C4.4 9.5 4.7 8.7 5 8.1M19.2 15.4C19.2 15.4 19.2 15.5 19.2 15.4C19.1 15.6 19 15.8 18.9 15.9V16.1C18.5 16.8 18 17.3 17.5 17.9L21.6 17.6L19.9 13.9C19.7 14.4 19.5 14.9 19.2 15.4M5.2 16.2C5.2 16.1 5.1 16.1 5.1 16C5 15.9 5 15.9 5 15.8C4.9 15.6 4.8 15.5 4.8 15.3C4.6 14.8 4.4 14.3 4.3 13.8L2.6 17.5L6.7 17.8C6 17.3 5.6 16.8 5.2 16.2M12.6 20H11.4C10.8 20 10.2 19.8 9.7 19.7L12 23L14.3 19.7C13.8 19.8 13.2 19.9 12.6 20M16.2 7.8C13.9 5.5 10.1 5.5 7.7 7.8S5.4 13.9 7.7 16.3 13.8 18.6 16.2 16.3 18.6 10.1 16.2 7.8M8.5 15.5L10.6 10.6L15.6 8.4L13.5 13.3L8.5 15.5M12.7 12.7C12.3 13.1 11.7 13.1 11.3 12.7C10.9 12.3 10.9 11.7 11.3 11.3C11.7 10.9 12.3 10.9 12.7 11.3C13.1 11.7 13.1 12.3 12.7 12.7Z";
const sunAbs = toAbsolute(parseSVGPath(sunSvg));
console.log('final inti = Path()');
console.log(toFlutter(sunAbs, 24, 24) + ';');

// ── Generate Twemoji Llama outline from its SVG paths ──
console.log('\n' + '='.repeat(60));
console.log('TWEMOJI LLAMA BODY (main path - outline only)');
console.log('='.repeat(60));
// The main body/contour path from twemoji llama (the large brown shape)
const llamaSvg = "M8.191.736c.328.339.735 2.394.735 2.394s1.282.092 2.407.786c4.5 2.776 2.542 9.542 3.944 11.102.432.48 9.681-1.643 14.222.544 3.844 1.852 3.083 4.646 4.083 5.271.758.474-2 1.25-2.578-2.313-.506 11.147-1.072 13.867-1.672 16.354-.339 1.406-1.979 1.601-1.792-.333.1-1.027.463-7.223-.583-8.792-.75-1.125-4.708 2.417-11.707 1.773-.485 4.276-1.097 7.136-1.272 7.519-.562 1.229-1.863 1.218-1.676-.009.187-1.228.447-4.949-.884-9.01-5.626-3.98-1.626-14.189-3.253-16.146-.362-.435-2.647-.981-3.314-1.048-.666-.067-1.265-.172-1.664-.239-.4-.067-.994-1.776-.927-2.242s.394-.623 1.26-.956.988-.222.942-.728c-.097-1.052 2.183-1.774 3.481-1.645-.133-.133-1.08-1.786-1.354-2.393-.35-.774 1.068-.442 1.602.111z";
const llamaAbs = toAbsolute(parseSVGPath(llamaSvg));
console.log('final llama = Path()');
console.log(toFlutter(llamaAbs, 36, 36) + ';');

console.log('\n\n// ========================================');
console.log('// SCALED FLUTTER CODE (using s for scale)');
console.log('// Usage: canvas.save(); canvas.translate(x, y); canvas.scale(s);');
console.log('// Then draw the path with stroke paint');
console.log('// ========================================');

// Generate code using a scale variable instead of normalized
function toFlutterScaled(absCommands, viewBoxW, viewBoxH) {
  const lines = [];
  // Center the path: offset so it's centered in the viewBox
  const n = (v) => {
    return (v).toFixed(2);
  };

  for (const cmd of absCommands) {
    switch (cmd.type) {
      case 'M':
        lines.push(`  ..moveTo(${n(cmd.x)}, ${n(cmd.y)})`);
        break;
      case 'L':
        lines.push(`  ..lineTo(${n(cmd.x)}, ${n(cmd.y)})`);
        break;
      case 'C':
        lines.push(`  ..cubicTo(${n(cmd.x1)}, ${n(cmd.y1)}, ${n(cmd.x2)}, ${n(cmd.y2)}, ${n(cmd.x)}, ${n(cmd.y)})`);
        break;
      case 'Q':
        lines.push(`  ..quadraticBezierTo(${n(cmd.x1)}, ${n(cmd.y1)}, ${n(cmd.x)}, ${n(cmd.y)})`);
        break;
      case 'Z':
        lines.push(`  ..close()`);
        break;
    }
  }
  return lines.join('\n');
}

// Show centered versions (translate by -center so origin is at center)
console.log('\n// AIRPLANE (centered, viewbox 24x24, translate to position first)');
console.log('final airplane = Path()');
console.log(toFlutterScaled(airplaneAbs, 24, 24) + ';');

console.log('\n// CONDOR/BIRD (centered, viewbox 24x24)');
console.log('final condor = Path()');
console.log(toFlutterScaled(birdAbs, 24, 24) + ';');

console.log('\n// PYRAMID (centered, viewbox 24x24)');
console.log('final pyramid = Path()');
console.log(toFlutterScaled(pyramidAbs, 24, 24) + ';');

console.log('\n// INTI/SUN (centered, viewbox 24x24)');
console.log('final inti = Path()');
console.log(toFlutterScaled(sunAbs, 24, 24) + ';');

console.log('\n// LLAMA (centered, viewbox 36x36)');
console.log('final llama = Path()');
console.log(toFlutterScaled(llamaAbs, 36, 36) + ';');
