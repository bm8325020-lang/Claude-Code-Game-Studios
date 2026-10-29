// Login no Mixamo (conta separada do dono). Uso: MX_EMAIL=... MX_SENHA=... node tools/mixamo_login.js
// Salva a sessão em /root/.mixamo_sessao/estado.json (fora do git). Se pedir código, escrever em /root/.mixamo_sessao/codigo.txt.
// Rodar em segundo plano, sem timeout curto: espera o código até 25 min.
const { chromium } = require('playwright');
const fs = require('fs');
const D = '/root/.mixamo_sessao';
(async () => {
  const b = await chromium.launch({ args: ['--disable-blink-features=AutomationControlled'] });
  const ctx = await b.newContext({ storageState: D + '/estado.json', userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36', locale: 'pt-BR', viewport: { width: 1280, height: 800 } });
  const p = await ctx.newPage();
  const txt = async () => (await p.innerText('body').catch(() => '')).replace(/\s+/g, ' ').slice(0, 220);
  await p.goto('https://www.mixamo.com/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForTimeout(5000);
  const login = p.getByText('Log in', { exact: false }).first();
  if (await login.isVisible().catch(() => false)) { await login.click(); await p.waitForTimeout(8000); }
  for (let passo = 0; passo < 6; passo++) {
    const t = await txt();
    console.log('PASSO', passo, p.url().slice(0, 50), t.slice(0, 120));
    if (new URL(p.url()).hostname.endsWith('mixamo.com')) break;
    if (await p.locator('input[type=email]:visible, input[name=username]:visible').count()) {
      await p.locator('input[type=email]:visible, input[name=username]:visible').first().fill(process.env.MX_EMAIL);
      await p.keyboard.press('Enter');
    } else if (await p.locator('input[type=password]:visible').count()) {
      await p.locator('input[type=password]:visible').first().fill(process.env.MX_SENHA);
      await p.keyboard.press('Enter');
    } else if (/Enter the code/i.test(t)) {
      console.log('PRECISA_CODIGO');
      const arq = D + '/codigo.txt';
      for (let i = 0; i < 300 && !fs.existsSync(arq); i++) await p.waitForTimeout(5000);
      const cod = fs.readFileSync(arq, 'utf8').trim(); fs.unlinkSync(arq);
      await p.locator('input:visible').first().click();
      await p.keyboard.type(cod, { delay: 180 });
    } else if (/verification code/i.test(t)) {
      await p.getByRole('button', { name: /continue/i }).first().click().catch(() => {});
    } else {
      await p.getByRole('button', { name: /continue|skip|not now|later/i }).first().click().catch(() => {});
    }
    await p.waitForTimeout(10000);
  }
  await p.waitForTimeout(5000);
  await p.screenshot({ path: D + '/5_final.png' });
  await ctx.storageState({ path: D + '/estado.json' });
  const tok = await p.evaluate(() => localStorage.getItem('access_token')).catch(() => null);
  console.log('FIM', p.url().slice(0, 60), 'TOKEN', tok ? 'SIM' : 'NAO');
  await b.close();
})().catch(e => { console.log('ERRO', e.message.slice(0, 300)); process.exit(1); });
