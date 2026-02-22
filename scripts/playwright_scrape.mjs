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

        const imgEl = item.querySelector('img');
        const img = imgEl?.getAttribute('data-src') || imgEl?.getAttribute('src') || '';

        results.push({ title, priceText, link, img });
      });
      return results;
    });

    return products.map((p) => ({
      title: p.title,
      priceText: p.priceText,
      url: p.link.startsWith('http') ? p.link : `https://www.jumia.com.gh${p.link}`,
      image_url: p.img.startsWith('http') ? p.img : `https://www.jumia.com.gh${p.img}`
    }));
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
