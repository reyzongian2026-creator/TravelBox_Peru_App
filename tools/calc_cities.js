// Peru bounding box from the GeoJSON data (approximate)
const lonMin = -81.33, lonMax = -68.65;
const latMin = -18.35, latMax = -0.04;

function norm(lat, lon) {
  const x = (lon - lonMin) / (lonMax - lonMin);
  const y = (latMax - lat) / (latMax - latMin);
  return { x: x.toFixed(3), y: y.toFixed(3) };
}

const places = {
  'Lima':            [-12.046, -77.043],
  'Cusco':           [-13.532, -71.968],
  'Arequipa':        [-16.409, -71.537],
  'Iquitos':         [-3.749, -73.254],
  'Puno':            [-15.840, -70.022],
  'Trujillo':        [-8.112, -79.029],
  'Nazca':           [-14.839, -75.114],
  'Huaraz':          [-9.528, -77.529],
  'Paracas':         [-13.835, -76.250],
  'Machu Picchu':    [-13.163, -72.545],
  'Lago Titicaca':   [-15.830, -69.340],
  'Chachapoyas':     [-6.231, -77.869],
  'Máncora':         [-4.104, -81.045],
  'Colca':           [-15.637, -71.882],
  'Huacachina':      [-14.087, -75.763],
  'Tarapoto':        [-6.489, -76.365],
  'Cajamarca':       [-7.164, -78.500],
  'Ayacucho':        [-13.158, -74.224],
  'Puerto Maldonado':[-12.593, -69.189],
};

for (const [name, [lat, lon]] of Object.entries(places)) {
  const {x, y} = norm(lat, lon);
  console.log(`  '${name}': Offset(mapX + mapW * ${x}, mapY + mapH * ${y}),`);
}
