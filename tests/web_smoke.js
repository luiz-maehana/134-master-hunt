// Teste da versão Web no navegador: abre o jogo exportado, pula a abertura, começa uma partida
// (Enter no botão "Começar", que já vem com o foco), espera a cidade carregar e falha se o motor
// registrar erro. Capturas de cada etapa em <saída>/ para conferir no artefato do CI.
// Roda no CI: node tests/web_smoke.js <url> <saída>  (playwright@1.49.1)
// No CI o navegador desenha por software (SwiftShader): é lento, então só confere que nada quebra.
const { chromium } = require('playwright');

const [url, out] = process.argv.slice(2);
// Avisos do navegador que não são do jogo.
const IGNORED = [/AudioContext was not allowed/, /WebGL/i, /GPU stall/i, /favicon/, /pointer ?lock/i];

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  const problems = [];
  page.on('console', (m) => {
    const text = m.text();
    if (IGNORED.some((re) => re.test(text))) return;
    if (m.type() === 'error' || /SCRIPT ERROR|^ERROR:|Cannot get class|not available/.test(text)) problems.push(text);
  });
  page.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
  // Captura com folga: no SwiftShader um quadro da cidade pode levar dezenas de segundos. Se nem
  // assim sair, só avisa (o que reprova é erro do motor no console).
  const shot = async (name) => {
    try {
      await page.screenshot({ path: `${out}/${name}.png`, timeout: 120000 });
    } catch (e) {
      console.log(`captura ${name} não saiu (desenho por software lento): ${e.message.split('\n')[0]}`);
    }
  };

  await page.goto(url);
  await page.waitForFunction(() => {
    const s = document.getElementById('status');
    if (!s) return true;
    const st = getComputedStyle(s);
    return st.display === 'none' || st.visibility === 'hidden' || st.opacity === '0';
  }, null, { timeout: 240000 });
  await page.waitForTimeout(5000);
  await shot('01_abertura');

  // Qualquer tecla pula a abertura com o logo; depois Enter aperta "Começar".
  await page.keyboard.press('Space');
  await page.waitForTimeout(4000);
  await shot('02_titulo');
  await page.keyboard.press('Enter');
  // Carregar a cidade e espalhar as moedas por software leva tempo.
  await page.waitForTimeout(150000);
  await shot('03_cidade');
  await browser.close();

  if (problems.length) {
    console.error('Erros do motor na versão Web:\n  ' + problems.slice(0, 20).join('\n  '));
    process.exit(1);
  }
  console.log('Web: abertura, título e cidade sem erro do motor.');
})().catch((e) => { console.error(e); process.exit(1); });
