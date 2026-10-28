const CACHE = 'fixme-shell-v4';
const IMAGES = [
  'bustling-mediterranean-harbor-town.webp',
  'cheerful-dragon-in-a-mountain-meadow.webp',
  'chibi-astronaut-on-the-moon.webp',
  'colourful-european-farmers-market-stall.webp',
  'dragonlit-castle-courtyard.webp',
  'enchanted-alchemist-s-mountain-workshop.webp',
  'enchanting-cottage-garden-by-the-lake.webp',
  'red-bicycle-in-a-sunny-village-garden.webp',
  'steam-train-over-the-mountain-bridge.webp',
  'sunflower-in-a-sunny-garden.webp',
  'sunlit-mediterranean-market-square.webp',
  'sunny-countryside-cottage-garden.webp',
  'sunny-kitchen-fruit-bowl.webp',
  'sunny-mediterranean-cafe-street.webp',
  'sunny-windowsill-cat-and-garden.webp',
  'tropical-reef-adventure.webp',
  'tropical-waterfall-paradise-with-colourful-birds.webp',
  'vibrant-alien-waterfall-valley.webp',
  'whimsical-earth-moon-and-stars.webp',
  'whimsical-fox-in-a-sunlit-forest.webp',
  'whimsical-sunlit-bakery-cafe.webp',
  'Baby Dragon and Golden Bird Adventure.webp',
  'Cheerful Bicycle Ride Through the Countryside.webp',
  'Chibi Moon Friends Under Earthlight.webp',
  'Curious Robot in an Alien Valley.webp',
  'Enchanted Bakery and Tiny Cobblers.webp',
  'Enchanted Garden Princess Reflections.webp',
  'Enchanted Waterfall Forest Valley.webp',
  'Golden Fish at the Storybook Harbour.webp',
  'Golden Goose Through the Sunflower Garden.webp',
  'Pancakes and Birds by the Cottage Window.webp',
  'Stardust Garden Observatory at Night.webp',
  'Sunlit Castle Courtyard with Sleeping Princess and Dragons.webp',
  'Sunny Storybook Village Street.webp',
  'The Alchemist’s Cozy Starlit Workshop.webp',
  'Twilight Fairytale Village Square.webp',
  'Whimsical Fox Meadow Fairytale.webp',
  'Whimsical Rapunzel Cottage by the Lake.webp',
  'Whimsical Valley Steam Train.webp',
  'Whimsical Woodland Picnic with a Hidden Wolf.webp',
  'Wholesome Mouse Chefs’ Cottage Kitchen.webp',
  'Woodland Lantern Concert.webp'
];
const SHELL = ['./index.html', './manifest.webmanifest', './icon.svg', ...IMAGES.map(image => `./images/${image}`)];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).then(response => {
      const copy = response.clone();
      caches.open(CACHE).then(cache => cache.put('./index.html', copy));
      return response;
    }).catch(() => caches.match('./index.html')));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
});
