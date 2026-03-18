class PeruTourismInfo {
  const PeruTourismInfo({
    required this.city,
    required this.region,
    required this.heroLandmark,
    required this.highlights,
    required this.shortDescription,
  });

  final String city;
  final String region;
  final String heroLandmark;
  final List<String> highlights;
  final String shortDescription;
}

class PeruTourismCatalog {
  const PeruTourismCatalog._();

  static const featured = <PeruTourismInfo>[
    PeruTourismInfo(
      city: 'Lima',
      region: 'Costa',
      heroLandmark: 'Costa Verde y Miraflores',
      highlights: [
        'Centro Histórico de Lima',
        'Barranco y Puente de los Suspiros',
        'Circuito de Playas',
      ],
      shortDescription:
          'Capital gastronómica y cultural con vista al Pacífico.',
    ),
    PeruTourismInfo(
      city: 'Cusco',
      region: 'Sierra',
      heroLandmark: 'Machu Picchu',
      highlights: ['Sacsayhuamán', 'Valle Sagrado', 'Plaza de Armas de Cusco'],
      shortDescription:
          'Puerta principal al legado inca y turismo de aventura.',
    ),
    PeruTourismInfo(
      city: 'Arequipa',
      region: 'Sierra',
      heroLandmark: 'Monasterio de Santa Catalina',
      highlights: ['Plaza de Armas', 'Cañón del Colca', 'Ruta del Sillar'],
      shortDescription:
          'Ciudad blanca, arquitectura volcánica y paisajes andinos.',
    ),
    PeruTourismInfo(
      city: 'Puno',
      region: 'Sierra',
      heroLandmark: 'Lago Titicaca',
      highlights: ['Islas Uros', 'Taquile', 'Sillustani'],
      shortDescription:
          'Experiencias vivenciales de altura en el lago navegable.',
    ),
    PeruTourismInfo(
      city: 'Trujillo',
      region: 'Costa',
      heroLandmark: 'Chan Chan',
      highlights: ['Huacas del Sol y la Luna', 'Huanchaco', 'Centro histórico'],
      shortDescription:
          'Historia precolombina y costa norte para surf y cultura.',
    ),
    PeruTourismInfo(
      city: 'Iquitos',
      region: 'Selva',
      heroLandmark: 'Amazonía peruana',
      highlights: ['Belén', 'Quistococha', 'Reserva Pacaya Samiria'],
      shortDescription: 'Acceso a la selva amazónica y ecoturismo fluvial.',
    ),
  ];

  static PeruTourismInfo forCity(String cityName) {
    final normalized = cityName.trim().toLowerCase();
    for (final item in featured) {
      if (item.city.toLowerCase() == normalized) {
        return item;
      }
    }
    return const PeruTourismInfo(
      city: 'Perú',
      region: 'Nacional',
      heroLandmark: 'Ruta turística TravelBox',
      highlights: ['Destinos históricos', 'Playas y costa', 'Andes y selva'],
      shortDescription:
          'Cobertura para viajeros en principales destinos del país.',
    );
  }
}
