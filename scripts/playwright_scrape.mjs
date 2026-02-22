import { chromium } from 'playwright';

const [store, query] = process.argv.slice(2);
if (!store || !query) {
  console.log(JSON.stringify([]));
  process.exit(0);
}

const scrapers = {
  Jumia: async (page, q) => {
    const url = `https://www.jumia.com.gh/catalog/?q=${encodeURIComponent(q)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(3000);

    const products = await page.evaluate(() => {
      const pickImage = (item) => {
        const direct = item.getAttribute('data-image') || item.getAttribute('data-img') || item.getAttribute('data-image-src');
        if (direct) return direct;
        const img = item.querySelector('img');
        const source = item.querySelector('source');
        const candidates = [];
        if (img) {
          ['data-src', 'data-srcset', 'srcset', 'src'].forEach((attr) => {
            const val = img.getAttribute(attr);
            if (val) candidates.push(val);
          });
        }
        if (source) {
          ['data-srcset', 'srcset'].forEach((attr) => {
            const val = source.getAttribute(attr);
            if (val) candidates.push(val);
          });
        }
        for (const val of candidates) {
          if (!val) continue;
          if (val.includes('data:image') || val.includes('placeholder') || val.includes('svg')) continue;
          const first = val.split(',')[0].trim();
          const url = first.split(' ')[0].trim();
          if (url) return url;
        }
        return '';
      };

      const items = document.querySelectorAll('article.prd, article, .prd, .product, [data-product], .item');
      const results = [];
      items.forEach((item) => {
        const titleEl = item.querySelector('[data-name]') || item.querySelector('.name') || item.querySelector('.title') || item.querySelector('h3') || item.querySelector('h4');
        const title = titleEl?.getAttribute('data-name') || titleEl?.textContent?.trim() || '';
        if (!title) return;

        const priceEl = item.querySelector('.prc') || item.querySelector('.price') || item.querySelector('.amount') || item.querySelector('.current-price');
        const priceText = priceEl?.textContent?.trim() || '';

        const linkEl = item.querySelector('a.core') || item.querySelector('a[href*="/product/"]') || item.querySelector('a');
        const link = linkEl?.getAttribute('href') || '';

        const img = pickImage(item);

        results.push({ title, priceText, link, img });
      });
      return results;
    });

    return products.map((p) => {
      const imageUrl = p.img.startsWith('http')
        ? p.img
        : p.img.startsWith('//')
          ? `https:${p.img}`
          : `https://www.jumia.com.gh${p.img}`;
      return {
        title: p.title,
        priceText: p.priceText,
        url: p.link.startsWith('http') ? p.link : `https://www.jumia.com.gh${p.link}`,
        image_url: imageUrl
      };
    });
  },
  Amazon: async (page, q) => {
    const url = `https://www.amazon.com/s?k=${encodeURIComponent(q)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(2000);

    const products = await page.evaluate(() => {
      const items = document.querySelectorAll('[data-component-type="s-search-result"]');
      const results = [];
      items.forEach((item) => {
        const title = item.querySelector('h2 span')?.textContent?.trim() || '';
        if (!title) return;

        const whole = item.querySelector('.a-price-whole')?.textContent?.trim() || '';
        const fraction = item.querySelector('.a-price-fraction')?.textContent?.trim() || '';
        const priceText = [whole, fraction].filter(Boolean).join('.') || '';

        const link = item.querySelector('a.a-link-normal')?.getAttribute('href') || '';
        const img = item.querySelector('img.s-image')?.getAttribute('src') || '';

        results.push({ title, priceText, link, img });
      });
      return results;
    });

    return products.map((p) => ({
      title: p.title,
      priceText: p.priceText,
      url: p.link.startsWith('http') ? p.link : `https://www.amazon.com${p.link}`,
      image_url: p.img
    }));
  },
  Jiji: async (page, q) => {
    const url = `https://jiji.com.gh/search?query=${encodeURIComponent(q)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(2000);

    const products = await page.evaluate(() => {
      const items = document.querySelectorAll('.qa-advert-list-item, .b-list-advert-base, .js-advert-list-item, article');
      const results = [];
      items.forEach((item) => {
        const titleEl = item.querySelector('[class*=title]') || item.querySelector('h3') || item.querySelector('h4') || item.querySelector('h5');
        const title = titleEl?.textContent?.trim() || '';
        if (!title) return;

        const priceEl = item.querySelector('[class*=price]');
        const priceText = priceEl?.textContent?.trim() || '';

        const linkEl = item.querySelector('a[href*=".html"]') || item.querySelector('a[href]');
        const link = linkEl?.getAttribute('href') || '';

        const imgEl = item.querySelector('img');
        const img = imgEl?.getAttribute('data-src') || imgEl?.getAttribute('src') || '';

        results.push({ title, priceText, link, img });
      });
      return results;
    });

    return products.map((p) => {
      const imageUrl = p.img.startsWith('http')
        ? p.img
        : p.img.startsWith('//')
          ? `https:${p.img}`
          : `https://jiji.com.gh${p.img}`;
      return {
        title: p.title,
        priceText: p.priceText,
        url: p.link.startsWith('http') ? p.link : `https://jiji.com.gh${p.link}`,
        image_url: imageUrl
      };
    });
  }
};

const run = async () => {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-blink-features=AutomationControlled'
    ]
  });

  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1400, height: 900 }
  });
  const page = await context.newPage();

  let results = [];
  try {
    const scraper = scrapers[store];
    if (scraper) {
      results = await scraper(page, query);
    }
  } catch (error) {
    results = [];
  } finally {
    await browser.close();
  }

  console.log(JSON.stringify(results));
};

await run();
