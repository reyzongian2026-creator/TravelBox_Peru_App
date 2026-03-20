/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const { chromium, webkit, devices } = require('playwright');

const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:8088';
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const OUTPUT_DIR =
  process.env.OUTPUT_DIR ||
  path.join(process.cwd(), 'artifacts', `mobile-layout-audit-${timestamp}`);

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
};

const dashboardPayload = {
  periodLabel: 'Mes actual',
  generatedAt: '2026-03-20T13:10:00Z',
  summary: {
    reservations: 184,
    confirmedRevenue: 28640.5,
    uniqueClients: 151,
    completedReservations: 129,
    completionRate: 70.1,
    cancelledReservations: 21,
    cancellationRate: 11.4,
    activeReservations: 34,
    openIncidents: 6,
  },
  bestWarehouse: {
    warehouseName: 'Miraflores Hub',
    city: 'Lima',
    interactionCount: 58,
    confirmedRevenue: 7120.4,
  },
  trend: [
    { label: 'S1', reservations: 36, confirmedRevenue: 4720.0 },
    { label: 'S2', reservations: 42, confirmedRevenue: 5980.0 },
    { label: 'S3', reservations: 49, confirmedRevenue: 7445.0 },
    { label: 'S4', reservations: 57, confirmedRevenue: 10495.5 },
  ],
  statusBreakdown: [
    { status: 'CONFIRMED', label: 'Confirmadas', count: 97 },
    { status: 'STORED', label: 'Almacenadas', count: 29 },
    { status: 'READY_FOR_PICKUP', label: 'Listas para recojo', count: 18 },
    { status: 'OUT_FOR_DELIVERY', label: 'En delivery', count: 16 },
    { status: 'COMPLETED', label: 'Completadas', count: 129 },
    { status: 'CANCELLED', label: 'Canceladas', count: 21 },
  ],
  topWarehouses: [
    {
      warehouseName: 'Miraflores Hub',
      city: 'Lima',
      interactionCount: 58,
      confirmedRevenue: 7120.4,
    },
    {
      warehouseName: 'Cusco Centro',
      city: 'Cusco',
      interactionCount: 41,
      confirmedRevenue: 5630.1,
    },
    {
      warehouseName: 'Arequipa Plaza',
      city: 'Arequipa',
      interactionCount: 33,
      confirmedRevenue: 4490.0,
    },
    {
      warehouseName: 'Piura Norte',
      city: 'Piura',
      interactionCount: 27,
      confirmedRevenue: 3055.2,
    },
    {
      warehouseName: 'Trujillo Av. Espana',
      city: 'Trujillo',
      interactionCount: 19,
      confirmedRevenue: 2120.8,
    },
  ],
  topCities: [
    { city: 'Lima', interactionCount: 64, incidentCount: 2, confirmedRevenue: 9320.0 },
    { city: 'Cusco', interactionCount: 42, incidentCount: 1, confirmedRevenue: 5780.5 },
    { city: 'Arequipa', interactionCount: 35, incidentCount: 1, confirmedRevenue: 4988.2 },
    { city: 'Piura', interactionCount: 24, incidentCount: 1, confirmedRevenue: 3190.4 },
    { city: 'Trujillo', interactionCount: 19, incidentCount: 1, confirmedRevenue: 2360.1 },
  ],
  topCouriers: [
    {
      fullName: 'Lucia Rivera',
      email: 'lucia.courier@travelbox.pe',
      activeDeliveryCount: 3,
      deliveryCompletedCount: 37,
    },
    {
      fullName: 'Diego Matos',
      email: 'diego.courier@travelbox.pe',
      activeDeliveryCount: 2,
      deliveryCompletedCount: 29,
    },
    {
      fullName: 'Ana Paredes',
      email: 'ana.courier@travelbox.pe',
      activeDeliveryCount: 1,
      deliveryCompletedCount: 24,
    },
  ],
  topOperators: [
    {
      fullName: 'Martin Vargas',
      email: 'martin.operator@travelbox.pe',
      activeDeliveryCount: 4,
      deliveryCreatedCount: 63,
    },
    {
      fullName: 'Sofia Luyo',
      email: 'sofia.operator@travelbox.pe',
      activeDeliveryCount: 2,
      deliveryCreatedCount: 51,
    },
    {
      fullName: 'Carlos Huaman',
      email: 'carlos.operator@travelbox.pe',
      activeDeliveryCount: 1,
      deliveryCreatedCount: 46,
    },
  ],
};

const warehouseItems = [
  {
    id: 101,
    name: 'Miraflores Hub',
    address: 'Av. Larco 880',
    city: 'Lima',
    district: 'Miraflores',
    latitude: -12.1216,
    longitude: -77.0297,
    openingHours: '06:00 - 23:00',
    priceFromPerHour: 5.2,
    pricePerHourSmall: 4.0,
    pricePerHourMedium: 5.2,
    pricePerHourLarge: 6.2,
    pricePerHourExtraLarge: 7.3,
    pickupFee: 16.0,
    dropoffFee: 16.0,
    insuranceFee: 8.5,
    score: 4.9,
    availableSlots: 28,
    extraServices: ['Seguro premium', 'Recojo express', 'Zona VIP'],
  },
  {
    id: 102,
    name: 'San Isidro Prime',
    address: 'Av. Canaval y Moreyra 320',
    city: 'Lima',
    district: 'San Isidro',
    latitude: -12.0972,
    longitude: -77.0308,
    openingHours: '07:00 - 22:00',
    priceFromPerHour: 5.5,
    pricePerHourSmall: 4.4,
    pricePerHourMedium: 5.5,
    pricePerHourLarge: 6.8,
    pricePerHourExtraLarge: 7.9,
    pickupFee: 17.0,
    dropoffFee: 17.0,
    insuranceFee: 8.0,
    score: 4.8,
    availableSlots: 20,
    extraServices: ['Pago QR', 'Check-in rapido'],
  },
  {
    id: 201,
    name: 'Cusco Centro',
    address: 'Calle Plateros 412',
    city: 'Cusco',
    district: 'Centro Historico',
    latitude: -13.5171,
    longitude: -71.978,
    openingHours: '06:00 - 22:00',
    priceFromPerHour: 4.8,
    pricePerHourSmall: 3.8,
    pricePerHourMedium: 4.8,
    pricePerHourLarge: 5.8,
    pricePerHourExtraLarge: 6.8,
    pickupFee: 18.0,
    dropoffFee: 18.0,
    insuranceFee: 7.2,
    score: 4.7,
    availableSlots: 16,
    extraServices: ['Atencion multilingue'],
  },
  {
    id: 301,
    name: 'Arequipa Plaza',
    address: 'Av. Ejercito 1400',
    city: 'Arequipa',
    district: 'Yanahuara',
    latitude: -16.3945,
    longitude: -71.5369,
    openingHours: '07:00 - 23:00',
    priceFromPerHour: 4.6,
    pricePerHourSmall: 3.7,
    pricePerHourMedium: 4.6,
    pricePerHourLarge: 5.5,
    pricePerHourExtraLarge: 6.5,
    pickupFee: 15.0,
    dropoffFee: 15.0,
    insuranceFee: 7.0,
    score: 4.6,
    availableSlots: 23,
    extraServices: ['Guarda flexible'],
  },
  {
    id: 401,
    name: 'Piura Norte',
    address: 'Av. Gulman 112',
    city: 'Piura',
    district: 'Piura',
    latitude: -5.1974,
    longitude: -80.6328,
    openingHours: '08:00 - 22:00',
    priceFromPerHour: 4.2,
    pricePerHourSmall: 3.5,
    pricePerHourMedium: 4.2,
    pricePerHourLarge: 5.0,
    pricePerHourExtraLarge: 5.8,
    pickupFee: 13.0,
    dropoffFee: 13.0,
    insuranceFee: 6.5,
    score: 4.5,
    availableSlots: 18,
    extraServices: ['Servicio 24/7 por reserva'],
  },
];

const reservations = [
  {
    id: '9001',
    code: 'TBX-9QX2A1',
    userId: 'u-client-01',
    warehouse: warehouseItems[0],
    startAt: '2026-03-20T13:00:00Z',
    endAt: '2026-03-21T17:00:00Z',
    bagCount: 2,
    totalPrice: 148.6,
    status: 'CONFIRMED',
    pickupRequested: true,
    dropoffRequested: false,
    timeline: [{ status: 'CONFIRMED', timestamp: '2026-03-20T13:00:00Z', message: 'Reserva confirmada.' }],
  },
  {
    id: '9002',
    code: 'TBX-8KB5C3',
    userId: 'u-client-02',
    warehouse: warehouseItems[1],
    startAt: '2026-03-19T10:00:00Z',
    endAt: '2026-03-22T12:30:00Z',
    bagCount: 1,
    totalPrice: 93.4,
    status: 'STORED',
    pickupRequested: false,
    dropoffRequested: true,
    timeline: [{ status: 'STORED', timestamp: '2026-03-19T10:00:00Z', message: 'Equipaje almacenado.' }],
  },
  {
    id: '9003',
    code: 'TBX-2NM7D8',
    userId: 'u-client-03',
    warehouse: warehouseItems[2],
    startAt: '2026-03-18T09:30:00Z',
    endAt: '2026-03-20T20:00:00Z',
    bagCount: 3,
    totalPrice: 174.2,
    status: 'READY_FOR_PICKUP',
    pickupRequested: false,
    dropoffRequested: true,
    timeline: [{ status: 'READY_FOR_PICKUP', timestamp: '2026-03-20T12:30:00Z', message: 'Lista para recojo.' }],
  },
  {
    id: '9004',
    code: 'TBX-4PL9E2',
    userId: 'u-client-04',
    warehouse: warehouseItems[3],
    startAt: '2026-03-18T08:10:00Z',
    endAt: '2026-03-20T15:45:00Z',
    bagCount: 2,
    totalPrice: 126.7,
    status: 'OUT_FOR_DELIVERY',
    pickupRequested: false,
    dropoffRequested: true,
    timeline: [{ status: 'OUT_FOR_DELIVERY', timestamp: '2026-03-20T11:20:00Z', message: 'Courier en ruta.' }],
  },
  {
    id: '9005',
    code: 'TBX-6RT1F0',
    userId: 'u-client-05',
    warehouse: warehouseItems[4],
    startAt: '2026-03-16T11:00:00Z',
    endAt: '2026-03-17T18:00:00Z',
    bagCount: 1,
    totalPrice: 62.0,
    status: 'COMPLETED',
    pickupRequested: false,
    dropoffRequested: false,
    timeline: [{ status: 'COMPLETED', timestamp: '2026-03-17T18:00:00Z', message: 'Reserva completada.' }],
  },
  {
    id: '9006',
    code: 'TBX-1ZA8G5',
    userId: 'u-client-06',
    warehouse: warehouseItems[0],
    startAt: '2026-03-15T07:20:00Z',
    endAt: '2026-03-16T19:30:00Z',
    bagCount: 2,
    totalPrice: 118.3,
    status: 'CANCELLED',
    pickupRequested: false,
    dropoffRequested: false,
    timeline: [{ status: 'CANCELLED', timestamp: '2026-03-15T10:40:00Z', message: 'Cancelada por cliente.' }],
  },
  {
    id: '9007',
    code: 'TBX-5VC3H7',
    userId: 'u-client-07',
    warehouse: warehouseItems[1],
    startAt: '2026-03-20T05:00:00Z',
    endAt: '2026-03-20T21:00:00Z',
    bagCount: 4,
    totalPrice: 244.5,
    status: 'CHECKIN_PENDING',
    pickupRequested: false,
    dropoffRequested: false,
    timeline: [{ status: 'CHECKIN_PENDING', timestamp: '2026-03-20T05:00:00Z', message: 'Check-in pendiente.' }],
  },
  {
    id: '9008',
    code: 'TBX-0QW4J6',
    userId: 'u-client-08',
    warehouse: warehouseItems[2],
    startAt: '2026-03-20T06:30:00Z',
    endAt: '2026-03-21T13:15:00Z',
    bagCount: 3,
    totalPrice: 197.9,
    status: 'CONFIRMED',
    pickupRequested: true,
    dropoffRequested: false,
    timeline: [{ status: 'CONFIRMED', timestamp: '2026-03-20T06:30:00Z', message: 'Reserva confirmada.' }],
  },
  {
    id: '9009',
    code: 'TBX-7EF2K1',
    userId: 'u-client-09',
    warehouse: warehouseItems[3],
    startAt: '2026-03-20T09:00:00Z',
    endAt: '2026-03-22T09:00:00Z',
    bagCount: 2,
    totalPrice: 161.4,
    status: 'STORED',
    pickupRequested: false,
    dropoffRequested: true,
    timeline: [{ status: 'STORED', timestamp: '2026-03-20T09:00:00Z', message: 'Equipaje almacenado.' }],
  },
  {
    id: '9010',
    code: 'TBX-3AL5L9',
    userId: 'u-client-10',
    warehouse: warehouseItems[4],
    startAt: '2026-03-20T10:00:00Z',
    endAt: '2026-03-21T08:00:00Z',
    bagCount: 1,
    totalPrice: 74.5,
    status: 'READY_FOR_PICKUP',
    pickupRequested: false,
    dropoffRequested: false,
    timeline: [{ status: 'READY_FOR_PICKUP', timestamp: '2026-03-20T14:10:00Z', message: 'Lista para recojo.' }],
  },
];

const incidents = [
  {
    id: '1301',
    reservationId: '9002',
    reservationCode: 'TBX-8KB5C3',
    reservationStatus: 'STORED',
    warehouseName: 'San Isidro Prime',
    warehouseAddress: 'Av. Canaval y Moreyra 320',
    openedByName: 'Sofia Cueva',
    openedByEmail: 'sofia.cueva@travelbox.pe',
    customerName: 'Marina Salas',
    customerEmail: 'marina.salas@mail.com',
    customerPhone: '+51983456123',
    customerWhatsappUrl: 'https://wa.me/51983456123',
    customerCallUrl: 'tel:+51983456123',
    status: 'OPEN',
    description: 'Cliente reporta cierre roto en maleta azul. EVIDENCIA: https://picsum.photos/seed/tbx1301/920/560',
    resolution: null,
  },
  {
    id: '1302',
    reservationId: '9004',
    reservationCode: 'TBX-4PL9E2',
    reservationStatus: 'OUT_FOR_DELIVERY',
    warehouseName: 'Arequipa Plaza',
    warehouseAddress: 'Av. Ejercito 1400',
    openedByName: 'Miguel Tapia',
    openedByEmail: 'miguel.tapia@travelbox.pe',
    customerName: 'Andres Loli',
    customerEmail: 'andres.loli@mail.com',
    customerPhone: '+51987123456',
    customerWhatsappUrl: 'https://wa.me/51987123456',
    customerCallUrl: 'tel:+51987123456',
    status: 'OPEN',
    description: 'Retraso por congestion en ruta principal.',
    resolution: null,
  },
  {
    id: '1303',
    reservationId: '9006',
    reservationCode: 'TBX-1ZA8G5',
    reservationStatus: 'CANCELLED',
    warehouseName: 'Miraflores Hub',
    warehouseAddress: 'Av. Larco 880',
    openedByName: 'TravelBox BOT',
    openedByEmail: 'bot@travelbox.pe',
    customerName: 'Rosa Caceres',
    customerEmail: 'rosa.caceres@mail.com',
    customerPhone: '+51993222111',
    customerWhatsappUrl: null,
    customerCallUrl: null,
    status: 'RESOLVED',
    description: 'Reembolso pendiente de confirmacion bancaria.',
    resolution: 'Reembolso aprobado y notificado por correo.',
  },
  {
    id: '1304',
    reservationId: '9010',
    reservationCode: 'TBX-3AL5L9',
    reservationStatus: 'READY_FOR_PICKUP',
    warehouseName: 'Piura Norte',
    warehouseAddress: 'Av. Gulman 112',
    openedByName: 'Daniel Castro',
    openedByEmail: 'daniel.castro@travelbox.pe',
    customerName: 'Lucia Quiroz',
    customerEmail: 'lucia.quiroz@mail.com',
    customerPhone: '+51994555111',
    customerWhatsappUrl: 'https://wa.me/51994555111',
    customerCallUrl: 'tel:+51994555111',
    status: 'RESOLVED',
    description: 'Cliente no encontro ticket de retiro al llegar a sede.',
    resolution: 'Se valido identidad y se genero nuevo ticket QR.',
  },
  {
    id: '1305',
    reservationId: '9008',
    reservationCode: 'TBX-0QW4J6',
    reservationStatus: 'CONFIRMED',
    warehouseName: 'Cusco Centro',
    warehouseAddress: 'Calle Plateros 412',
    openedByName: 'Lia Gonzales',
    openedByEmail: 'lia.gonzales@travelbox.pe',
    customerName: 'Jorge Flores',
    customerEmail: 'jorge.flores@mail.com',
    customerPhone: '+51991234987',
    customerWhatsappUrl: null,
    customerCallUrl: null,
    status: 'OPEN',
    description: 'Solicitud de cambio de horario sin confirmar disponibilidad.',
    resolution: null,
  },
];

const adminUsers = [
  {
    id: 'au-01',
    fullName: 'Valeria Salinas',
    email: 'valeria.salinas@travelbox.pe',
    phone: '+51987654321',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '72839201',
    documentPhotoPath: 'https://picsum.photos/seed/doc1/320/200',
    vehiclePlate: null,
    active: true,
    roles: ['ADMIN'],
    warehouseIds: [101],
    warehouseNames: ['Miraflores Hub'],
    deliveryCreatedCount: 0,
    deliveryAssignedCount: 0,
    deliveryCompletedCount: 0,
    activeDeliveryCount: 0,
    createdAt: '2026-03-10T09:00:00Z',
  },
  {
    id: 'au-02',
    fullName: 'Martin Vargas',
    email: 'martin.operator@travelbox.pe',
    phone: '+51971234567',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '43981222',
    documentPhotoPath: 'https://picsum.photos/seed/doc2/320/200',
    vehiclePlate: null,
    active: true,
    roles: ['OPERATOR'],
    warehouseIds: [101, 102],
    warehouseNames: ['Miraflores Hub', 'San Isidro Prime'],
    deliveryCreatedCount: 63,
    deliveryAssignedCount: 28,
    deliveryCompletedCount: 47,
    activeDeliveryCount: 4,
    createdAt: '2026-03-12T11:00:00Z',
  },
  {
    id: 'au-03',
    fullName: 'Lucia Rivera',
    email: 'lucia.courier@travelbox.pe',
    phone: '+51970001234',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '44201671',
    documentPhotoPath: 'https://picsum.photos/seed/doc3/320/200',
    vehiclePlate: 'B5K-118',
    active: true,
    roles: ['COURIER'],
    warehouseIds: [101, 201],
    warehouseNames: ['Miraflores Hub', 'Cusco Centro'],
    deliveryCreatedCount: 0,
    deliveryAssignedCount: 44,
    deliveryCompletedCount: 37,
    activeDeliveryCount: 3,
    createdAt: '2026-03-13T08:10:00Z',
  },
  {
    id: 'au-04',
    fullName: 'Ana Paredes',
    email: 'ana.support@travelbox.pe',
    phone: '+51974445566',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '45821376',
    documentPhotoPath: null,
    vehiclePlate: null,
    active: true,
    roles: ['SUPPORT'],
    warehouseIds: [102],
    warehouseNames: ['San Isidro Prime'],
    deliveryCreatedCount: 5,
    deliveryAssignedCount: 2,
    deliveryCompletedCount: 2,
    activeDeliveryCount: 1,
    createdAt: '2026-03-14T16:42:00Z',
  },
  {
    id: 'au-05',
    fullName: 'Diego Matos',
    email: 'diego.courier@travelbox.pe',
    phone: '+51977788111',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '49127833',
    documentPhotoPath: null,
    vehiclePlate: 'C9R-224',
    active: false,
    roles: ['COURIER'],
    warehouseIds: [301],
    warehouseNames: ['Arequipa Plaza'],
    deliveryCreatedCount: 0,
    deliveryAssignedCount: 31,
    deliveryCompletedCount: 29,
    activeDeliveryCount: 0,
    createdAt: '2026-03-15T10:30:00Z',
  },
  {
    id: 'au-06',
    fullName: 'Sofia Luyo',
    email: 'sofia.operator@travelbox.pe',
    phone: '+51976660101',
    nationality: 'Peru',
    preferredLanguage: 'es',
    authProvider: 'LOCAL',
    managedByAdmin: true,
    documentType: 'DNI',
    documentNumber: '43677109',
    documentPhotoPath: null,
    vehiclePlate: null,
    active: true,
    roles: ['OPERATOR', 'CITY_SUPERVISOR'],
    warehouseIds: [301, 401],
    warehouseNames: ['Arequipa Plaza', 'Piura Norte'],
    deliveryCreatedCount: 51,
    deliveryAssignedCount: 16,
    deliveryCompletedCount: 34,
    activeDeliveryCount: 2,
    createdAt: '2026-03-16T11:20:00Z',
  },
];

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function fulfillJson(route, body, status = 200, extraHeaders = {}) {
  return route.fulfill({
    status,
    headers: {
      ...CORS_HEADERS,
      'content-type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
    body: JSON.stringify(body),
  });
}

function normalizeApiPath(url) {
  const raw = new URL(url).pathname;
  return raw.replace(/^\/api\/v1/, '');
}

function filterReservations(url) {
  const status = (url.searchParams.get('status') || '').trim().toUpperCase();
  const query = (url.searchParams.get('query') || '').trim().toLowerCase();
  return reservations.filter((item) => {
    const statusMatch = !status || (item.status || '').toUpperCase() === status;
    if (!statusMatch) return false;
    if (!query) return true;
    return (
      item.code.toLowerCase().includes(query) ||
      item.warehouse.name.toLowerCase().includes(query) ||
      item.warehouse.city.toLowerCase().includes(query) ||
      item.warehouse.district.toLowerCase().includes(query)
    );
  });
}

function filterIncidents(url) {
  const status = (url.searchParams.get('status') || '').trim().toUpperCase();
  const query = (url.searchParams.get('query') || '').trim().toLowerCase();
  return incidents.filter((item) => {
    const statusMatch = !status || status === 'ALL' || item.status.toUpperCase() === status;
    if (!statusMatch) return false;
    if (!query) return true;
    return (
      item.reservationCode.toLowerCase().includes(query) ||
      item.openedByName.toLowerCase().includes(query) ||
      item.description.toLowerCase().includes(query) ||
      item.customerName.toLowerCase().includes(query)
    );
  });
}

function filterAdminUsers(url) {
  const role = (url.searchParams.get('role') || '').trim().toUpperCase();
  const query = (url.searchParams.get('query') || '').trim().toLowerCase();
  return adminUsers.filter((item) => {
    const roleMatch = !role || role === 'ALL' || item.roles.includes(role);
    if (!roleMatch) return false;
    if (!query) return true;
    return (
      item.fullName.toLowerCase().includes(query) ||
      item.email.toLowerCase().includes(query) ||
      item.phone.toLowerCase().includes(query)
    );
  });
}

async function handleApiRoute(route, unknownRequests) {
  const request = route.request();
  const method = request.method().toUpperCase();
  const url = new URL(request.url());
  const pathName = normalizeApiPath(request.url());

  if (method === 'OPTIONS') {
    await route.fulfill({
      status: 204,
      headers: CORS_HEADERS,
      body: '',
    });
    return;
  }

  if (method === 'POST' && pathName === '/auth/login') {
    await fulfillJson(route, {
      accessToken: 'local-token-e2e-admin',
      refreshToken: 'local-refresh-e2e-admin',
      user: {
        id: 'admin-001',
        fullName: 'Admin TravelBox',
        firstName: 'Admin',
        lastName: 'TravelBox',
        name: 'Admin TravelBox',
        email: 'admin@travelbox.pe',
        role: 'ADMIN',
        roles: ['ADMIN'],
        phone: '+51999999999',
        preferredLanguage: 'es',
        emailVerified: true,
        profileCompleted: true,
      },
    });
    return;
  }

  if (method === 'GET' && pathName === '/profile/me/onboarding-status') {
    await fulfillJson(route, { completed: true, onboardingCompleted: true });
    return;
  }

  if (method === 'POST' && pathName === '/profile/me/onboarding-complete') {
    await fulfillJson(route, { completed: true, onboardingCompleted: true });
    return;
  }

  if (method === 'GET' && pathName === '/notifications/stream') {
    await fulfillJson(route, { cursor: 0, items: [] });
    return;
  }

  if (method === 'GET' && pathName === '/notifications/my') {
    await fulfillJson(route, { items: [] });
    return;
  }

  if (pathName === '/notifications/events') {
    await route.fulfill({
      status: 204,
      headers: CORS_HEADERS,
      body: '',
    });
    return;
  }

  if (
    method === 'GET' &&
    (pathName === '/admin/dashboard' ||
      pathName === '/admin/dashboard/summary' ||
      pathName === '/admin/stats' ||
      pathName === '/admin/overview')
  ) {
    await fulfillJson(route, dashboardPayload);
    return;
  }

  if (
    method === 'GET' &&
    (pathName === '/warehouses/search' || pathName === '/geo/warehouses/search')
  ) {
    await fulfillJson(route, warehouseItems);
    return;
  }

  if (method === 'GET' && pathName.startsWith('/warehouses/')) {
    const id = pathName.split('/').pop();
    const warehouse = warehouseItems.find((item) => item.id.toString() === id);
    await fulfillJson(route, warehouse || warehouseItems[0]);
    return;
  }

  if (method === 'GET' && pathName === '/reservations/page') {
    const filtered = filterReservations(url);
    await fulfillJson(route, {
      page: 0,
      size: filtered.length,
      last: true,
      items: filtered,
    });
    return;
  }

  if (method === 'GET' && pathName === '/reservations') {
    await fulfillJson(route, reservations);
    return;
  }

  if (method === 'GET' && /^\/reservations\/[^/]+$/.test(pathName)) {
    const reservationId = pathName.split('/').pop();
    const found = reservations.find((item) => item.id === reservationId);
    await fulfillJson(route, found || reservations[0]);
    return;
  }

  if (method === 'GET' && pathName === '/incidents') {
    await fulfillJson(route, filterIncidents(url));
    return;
  }

  if (method === 'GET' && pathName === '/admin/users') {
    await fulfillJson(route, filterAdminUsers(url));
    return;
  }

  if (method === 'GET' && pathName === '/admin/users/summary') {
    const filteredUsers = filterAdminUsers(url);
    const summary = {
      totalUsers: filteredUsers.length,
      activeUsers: filteredUsers.filter((item) => item.active).length,
      operatorUsers: filteredUsers.filter((item) => item.roles.includes('OPERATOR')).length,
      courierUsers: filteredUsers.filter((item) => item.roles.includes('COURIER')).length,
      completedDeliveries: filteredUsers.reduce(
        (sum, item) => sum + (item.deliveryCompletedCount || 0),
        0,
      ),
    };
    await fulfillJson(route, summary);
    return;
  }

  if (method === 'GET' && pathName === '/admin/warehouses') {
    const list = warehouseItems.map((item) => ({
      id: Number(item.id),
      name: item.name,
      cityName: item.city,
      active: true,
    }));
    await fulfillJson(route, list);
    return;
  }

  const key = `${method} ${pathName}`;
  unknownRequests[key] = (unknownRequests[key] || 0) + 1;

  if (method === 'GET') {
    await fulfillJson(route, {});
    return;
  }

  await route.fulfill({
    status: 204,
    headers: CORS_HEADERS,
    body: '',
  });
}

async function waitForUi(page, ms = 900) {
  await page.waitForTimeout(ms);
}

async function clickFirstAvailable(candidates, timeoutMs = 1800) {
  for (const locator of candidates) {
    try {
      if ((await locator.count()) > 0) {
        await locator.first().click({ timeout: timeoutMs });
        return true;
      }
    } catch (_error) {
      // Continue trying the next locator.
    }
  }
  return false;
}

async function attemptCoordinateLogin(page) {
  const viewport = page.viewportSize() || { width: 390, height: 844 };
  const centerX = Math.floor(viewport.width * 0.5);
  const modeInternalX = Math.floor(viewport.width * 0.74);
  const modeToggleY = Math.floor(viewport.height * 0.61);
  const emailTargets = [0.77, 0.80];

  await page.mouse.click(modeInternalX, modeToggleY);
  await page.waitForTimeout(140);

  for (const emailRatio of emailTargets) {
    const emailY = Math.floor(viewport.height * emailRatio);
    await page.mouse.click(centerX, emailY);
    await page.waitForTimeout(140);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type('admin@travelbox.pe', { delay: 28 });
    await page.keyboard.press('Tab');
    await page.waitForTimeout(110);
    await page.keyboard.type('Admin1234', { delay: 28 });
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1400);
    if (/\/admin\/dashboard/.test(page.url())) {
      return;
    }
  }
}

async function loginAsAdmin(page, debugDir) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'domcontentloaded' });
  await waitForUi(page, 1400);

  await clickFirstAvailable(
    [
      page.getByRole('button', { name: /Personal interno|Internal staff/i }),
      page.getByText(/Personal interno|Internal staff/i),
    ],
    1000,
  );

  const emailInputCandidates = [
    page.getByPlaceholder(/Correo electr[oó]nico|Email/i),
    page.locator('input[type="email"]'),
    page.locator('input').first(),
  ];
  const passwordInputCandidates = [
    page.getByPlaceholder(/Contrase[nñ]a|Password/i),
    page.locator('input[type="password"]'),
  ];

  let emailInput = null;
  for (const locator of emailInputCandidates) {
    if ((await locator.count()) > 0) {
      emailInput = locator.first();
      break;
    }
  }
  let passwordInput = null;
  for (const locator of passwordInputCandidates) {
    if ((await locator.count()) > 0) {
      passwordInput = locator.first();
      break;
    }
  }

  if (!emailInput || !passwordInput) {
    await attemptCoordinateLogin(page);
    try {
      await page.waitForURL(/\/admin\/dashboard/, { timeout: 16000 });
      await waitForUi(page, 1000);
      return;
    } catch (_error) {
      await page.screenshot({
        path: path.join(debugDir, 'login-failed.png'),
        fullPage: false,
      });
      throw new Error('No se encontro input de login ni se pudo autenticar por coordenadas.');
    }
  }

  await emailInput.fill('admin@travelbox.pe');
  await passwordInput.fill('Admin1234');

  const loginClicked = await clickFirstAvailable(
    [
      page.getByRole('button', {
        name: /Ingresar personal interno|Sign in as internal staff/i,
      }),
      page.getByText(/Ingresar personal interno|Sign in as internal staff/i),
    ],
    2500,
  );

  if (!loginClicked) {
    await passwordInput.press('Enter');
  }

  await page.waitForURL(/\/admin\/dashboard/, { timeout: 20000 });
  await waitForUi(page, 1200);
}

async function wheel(page, deltaY, steps, waitMs = 120) {
  const viewport = page.viewportSize() || { width: 390, height: 844 };
  await page.mouse.move(Math.floor(viewport.width * 0.5), Math.floor(viewport.height * 0.58));
  for (let index = 0; index < steps; index += 1) {
    await page.mouse.wheel(0, deltaY);
    await page.waitForTimeout(waitMs);
  }
}

async function dragScroll(page, direction, steps, waitMs = 120) {
  const viewport = page.viewportSize() || { width: 390, height: 844 };
  const x = Math.floor(viewport.width * 0.5);
  const startY = direction === 'down'
    ? Math.floor(viewport.height * 0.78)
    : Math.floor(viewport.height * 0.34);
  const endY = direction === 'down'
    ? Math.floor(viewport.height * 0.32)
    : Math.floor(viewport.height * 0.78);

  for (let index = 0; index < steps; index += 1) {
    await page.mouse.move(x, startY);
    await page.mouse.down();
    await page.mouse.move(x, endY, { steps: 10 });
    await page.mouse.up();
    await page.waitForTimeout(waitMs);
  }
}

async function captureStates(page, screenSlug, screenDir) {
  await waitForUi(page, 900);
  await page.screenshot({
    path: path.join(screenDir, `${screenSlug}-top-visible.png`),
    fullPage: false,
  });

  await dragScroll(page, 'down', 3, 110);
  await wheel(page, 640, 2, 80);
  await waitForUi(page, 70);
  await page.screenshot({
    path: path.join(screenDir, `${screenSlug}-scroll-down-hide.png`),
    fullPage: false,
  });

  await dragScroll(page, 'up', 2, 110);
  await wheel(page, -540, 1, 80);
  await waitForUi(page, 200);
  await page.screenshot({
    path: path.join(screenDir, `${screenSlug}-scroll-up-reveal.png`),
    fullPage: false,
  });

  await dragScroll(page, 'down', 22, 70);
  await wheel(page, 1050, 70, 70);
  await waitForUi(page, 420);
  await page.screenshot({
    path: path.join(screenDir, `${screenSlug}-bottom-end.png`),
    fullPage: false,
  });

  await dragScroll(page, 'up', 22, 50);
  await wheel(page, -1050, 70, 40);
}

async function openAndCapture(page, routePath, screenSlug, screenDir) {
  await page.goto(`${BASE_URL}/#${routePath}`, { waitUntil: 'domcontentloaded' });
  await waitForUi(page, 1400);
  console.log(`Ruta solicitada ${routePath} -> URL activa ${page.url()}`);
  await captureStates(page, screenSlug, screenDir);
}

async function resetDiscoveryTop(page) {
  await page.goto(`${BASE_URL}/#/discovery`, { waitUntil: 'domcontentloaded' });
  await waitForUi(page, 1200);
}

async function activateMapMode(page) {
  const activatedByLabel = await clickFirstAvailable(
    [
      page.getByRole('button', { name: /^Mapa$|^Map$/i }),
      page.getByRole('checkbox', { name: /^Mapa$|^Map$/i }),
      page.getByText(/^Mapa$|^Map$/i),
    ],
    1400,
  );
  if (activatedByLabel) {
    await waitForUi(page, 420);
    return true;
  }

  const viewport = page.viewportSize() || { width: 390, height: 844 };
  const tapPoints = [
    [0.44, 0.47],
    [0.50, 0.52],
    [0.55, 0.48],
    [0.50, 0.56],
    [0.50, 0.59],
  ];
  for (const [xRatio, yRatio] of tapPoints) {
    const x = Math.floor(viewport.width * xRatio);
    const y = Math.floor(viewport.height * yRatio);
    await page.mouse.click(x, y);
    await waitForUi(page, 340);
  }
  return true;
}

async function runProfile(profile) {
  const unknownApiRequests = {};
  const profileDir = path.join(OUTPUT_DIR, profile.name);
  ensureDir(profileDir);

  const browser = await profile.engine.launch({ headless: true });
  const context = await browser.newContext({
    ...profile.device,
    locale: 'es-PE',
    colorScheme: 'light',
  });

  const seededSession = {
    locale: 'es',
    user: {
      id: 'admin-001',
      name: 'Admin TravelBox',
      fullName: 'Admin TravelBox',
      firstName: 'Admin',
      lastName: 'TravelBox',
      email: 'admin@travelbox.pe',
      role: 'ADMIN',
      roles: ['ADMIN'],
      phone: '+51999999999',
      preferredLanguage: 'es',
      emailVerified: true,
      profileCompleted: true,
    },
    accessToken: 'local-token-seeded-admin',
    refreshToken: 'local-refresh-seeded-admin',
    pendingVerificationCode: null,
    onboardingCompleted: true,
  };

  await context.addInitScript((sessionState) => {
    const sessionKey = 'flutter.travelbox.session.v2';
    const onboardingKey = 'flutter.travelbox.onboarding.completed.users.v1';
    const encodedSession = JSON.stringify(JSON.stringify(sessionState));
    const encodedOnboardingUsers = JSON.stringify([sessionState.user.id]);
    window.localStorage.setItem(sessionKey, encodedSession);
    window.localStorage.setItem(onboardingKey, encodedOnboardingUsers);
  }, seededSession);

  await context.route('**/api/v1/**', (route) => handleApiRoute(route, unknownApiRequests));

  const page = await context.newPage();

  try {
    await page.goto(`${BASE_URL}/#/admin/dashboard`, { waitUntil: 'domcontentloaded' });
    await page.waitForURL(/#\/admin\/dashboard/, { timeout: 20000 });
    await waitForUi(page, 1400);
    await openAndCapture(page, '/admin/dashboard', 'dashboard', profileDir);
    await openAndCapture(page, '/discovery', 'mapa-lista', profileDir);
    await resetDiscoveryTop(page);
    await activateMapMode(page);
    if (!/#\/discovery/.test(page.url())) {
      await resetDiscoveryTop(page);
      await activateMapMode(page);
    }
    await waitForUi(page, 900);
    await captureStates(page, 'mapa-mapa', profileDir);

    await openAndCapture(page, '/admin/reservations', 'reservas', profileDir);
    await openAndCapture(page, '/admin/incidents', 'tickets', profileDir);
    await openAndCapture(page, '/admin/users', 'usuarios', profileDir);

    const report = {
      profile: profile.name,
      baseUrl: BASE_URL,
      capturedAt: new Date().toISOString(),
      unknownApiRequests,
    };
    fs.writeFileSync(
      path.join(profileDir, 'audit-report.json'),
      JSON.stringify(report, null, 2),
      'utf8',
    );
  } finally {
    await context.close();
    await browser.close();
  }
}

async function main() {
  ensureDir(OUTPUT_DIR);
  const iPhone = devices['iPhone 14 Pro'];
  const fullRunPlan = [
    {
      name: 'iphone-safari',
      engine: webkit,
      device: {
        ...iPhone,
        isMobile: false,
        hasTouch: false,
      },
    },
    {
      name: 'chrome-mobile',
      engine: chromium,
      device: devices['iPhone 14 Pro'],
    },
    {
      name: 'android-chrome',
      engine: chromium,
      device: devices['Pixel 7'],
    },
  ];

  const selectedProfiles = (process.env.AUDIT_PROFILES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const runPlan =
    selectedProfiles.length === 0
      ? fullRunPlan
      : fullRunPlan.filter((profile) => selectedProfiles.includes(profile.name));

  if (runPlan.length === 0) {
    throw new Error(
      `AUDIT_PROFILES no coincide con perfiles validos. Disponibles: ${fullRunPlan
        .map((profile) => profile.name)
        .join(', ')}`,
    );
  }

  for (const profile of runPlan) {
    console.log(`Capturando perfil: ${profile.name}`);
    await runProfile(profile);
  }

  console.log(`Capturas listas en: ${OUTPUT_DIR}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
