const List<String> nonAgriTerms = [
  // Phones, computers, gadgets
  'phone', 'smartphone', 'cellphone', 'iphone', 'samsung', 'android',
  'laptop', 'macbook', 'tablet', 'ipad', 'computer', 'desktop',
  'charger', 'power bank', 'powerbank', 'earphone', 'headphone', 'earbud',
  'airpods', 'speaker', 'camera', 'dslr', 'drone',
  // Gaming and TV
  'playstation', 'ps4', 'ps5', 'xbox', 'nintendo', 'console', 'television',
  'tv',
  // Clothing, shoes, accessories
  'shirt', 'dress', 'jeans', 'pants', 'jacket', 'hoodie', 'shoe', 'sneaker',
  'slipper', 'handbag', 'purse', 'wig',
  // Beauty and jewelry
  'perfume', 'cosmetic', 'makeup', 'lipstick', 'jewelry', 'jewellery',
  'necklace', 'bracelet', 'earring',
  // Appliances and vehicles
  'refrigerator', 'microwave', 'air conditioner', 'aircon',
  'washing machine', 'motorcycle',
  // Misc
  'toy',
];

final RegExp _nonAgriPattern = RegExp(
  r'\b(' + nonAgriTerms.map(RegExp.escape).join('|') + r')s?\b',
  caseSensitive: false,
);

bool looksNonAgricultural(String text) => _nonAgriPattern.hasMatch(text);

List<String> nonAgriMatches(String text) => _nonAgriPattern
    .allMatches(text)
    .map((m) => m.group(1)!.toLowerCase())
    .toSet()
    .toList();