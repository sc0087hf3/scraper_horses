import { chromium } from "playwright";
import fs from "fs";
import path from "path";

// ===============================
// 設定
// ===============================

// 出力フォルダ
const jsonDir = "/home/ubuntu/netkeiba/data/pedigree/json";
const logDir = "/home/ubuntu/netkeiba/data/logs";

// フォルダ作成（なければ作る）
if (!fs.existsSync(jsonDir)) fs.mkdirSync(jsonDir, { recursive: true });
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

// User-Agentリスト
const USER_AGENTS = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
];

// horse_ids.txt の読み込み
const horseIdFile = path.resolve("./horse_ids.txt");
const horseIds = fs.readFileSync(horseIdFile, "utf-8")
  .split("\n")
  .map(line => line.trim())
  .filter(Boolean);

// コマンド引数（例: node scrape_pedigree.js 0 500）
const args = process.argv.slice(2);
const startLine = args[0] ? parseInt(args[0], 10) : 0;
const endLine = args[1] ? parseInt(args[1], 10) : horseIds.length - 1;

console.log(`Processing lines ${startLine} to ${endLine} of ${horseIds.length}`);

// ===============================
// ランダムスリープ関数（1〜3秒）
// ===============================
function sleepRandom(min = 1000, max = 3000) {
  const ms = Math.floor(Math.random() * (max - min + 1)) + min;
  console.log(`⏳ Waiting ${ms}ms...`);
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ===============================
// メイン処理
// ===============================
(async () => {
  const browser = await chromium.launch({ headless: true });
  const allPedigree = {};
  const logLines = [];

  for (let i = startLine; i <= endLine && i < horseIds.length; i++) {
    const horseId = horseIds[i];
    const url = `https://db.netkeiba.com/horse/${horseId}/`;
    const randomUA = USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];

    const context = await browser.newContext({ userAgent: randomUA });
    const page = await context.newPage();

    console.log(`\n🐴 Fetching (${i}): ${horseId} with UA: ${randomUA}`);

    try {
      await page.goto(url, { waitUntil: "domcontentloaded" });
      await page.waitForSelector(".blood_table td a", { timeout: 5000 });

      // 血統データ抽出
      const pedigree = await page.$$eval(".blood_table tbody tr", (rows) => {
        const extractHorse = (el) => {
          if (!el) return null;
          const a = el.querySelector("a");
          if (!a) return null;
          const href = a.getAttribute("href");
          const idMatch = href?.match(/horse\/ped\/([^/]+)/);
          return idMatch ? { id: idMatch[1] } : null;
        };

        const fatherCell = rows[0].querySelector("td.b_ml");
        const father = extractHorse(fatherCell);
        const fatherFatherCell = rows[0].querySelector("td.b_ml:nth-of-type(2)");
        const fatherFather = extractHorse(fatherFatherCell);
        const fatherMotherCell = rows[1].querySelector("td.b_fml");
        const fatherMother = extractHorse(fatherMotherCell);

        const motherCell = rows[2].querySelector("td.b_fml");
        const mother = extractHorse(motherCell);
        const motherFatherCell = rows[2].querySelector("td.b_ml");
        const motherFather = extractHorse(motherFatherCell);
        const motherMotherCell = rows[3].querySelector("td.b_fml");
        const motherMother = extractHorse(motherMotherCell);

        return {
          father: { ...father, father: fatherFather ?? null, mother: fatherMother ?? null },
          mother: { ...mother, father: motherFather ?? null, mother: motherMother ?? null },
        };
      });

      allPedigree[horseId] = pedigree;
      logLines.push(`${horseId}: SUCCESS`);
      console.log(`✅ SUCCESS: ${horseId}`);

    } catch (err) {
      console.error(`❌ FAILED: ${horseId} (${err.message})`);
      allPedigree[horseId] = null;
      logLines.push(`${horseId}: FAILED`);
    }

    await page.close();
    await context.close();

    // 🕒 ランダムスリープ（1〜4秒）
    await sleepRandom(1000, 4000);
  }

  await browser.close();

  // ===============================
  // 出力
  // ===============================
  const jsonPath = path.join(jsonDir, `pedigree_${startLine}_${endLine}.json`);
  fs.writeFileSync(jsonPath, JSON.stringify(allPedigree, null, 2), "utf-8");

  const logPath = path.join(logDir, `pedigree_${startLine}_${endLine}.log`);
  fs.writeFileSync(logPath, logLines.join("\n"), "utf-8");

  console.log(`\n💾 Saved JSON to: ${jsonPath}`);
  console.log(`🧾 Saved log to:  ${logPath}`);
})();
