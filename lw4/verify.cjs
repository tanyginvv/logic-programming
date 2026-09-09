// Запасной запуск тестов через SWI-Prolog WebAssembly, если swipl не установлен.
// npm.cmd install --prefix .runtime swipl-wasm@8.1.2 --cache .runtime/npm-cache --ignore-scripts
const fs = require('node:fs');
const path = require('node:path');
const localRuntime = path.join(__dirname, '.runtime/node_modules/swipl-wasm');
const sharedRuntime = path.join(__dirname, '../.runtime/node_modules/swipl-wasm');
const SWIPL = require(fs.existsSync(localRuntime) ? localRuntime : sharedRuntime);
(async () => {
  const pl = await SWIPL({ arguments: ['-q'] });
  for (const name of ['hotel_expert.pl', 'hotel_tests.pl']) {
    pl.FS.writeFile('/' + name, fs.readFileSync(path.join(__dirname, name)));
  }
  console.log('SWI-Prolog:', pl.prolog.query('current_prolog_flag(version_data, V)').once());
  const loaded = pl.prolog.query("consult('/hotel_tests.pl')").once();
  if (!loaded || loaded.success === false) throw new Error('Не удалось загрузить программу');
  const result = pl.prolog.query('run_tests').once();
  console.log('run_tests:', result);
  if (!result || result.success === false) throw new Error('Тесты не пройдены');
  console.log('Число тестов:', pl.prolog.query("findall(N, plunit_hotel:'unit test'(N,_,_,_), Ns), length(Ns, Count)").once());
  const demo = pl.prolog.query('hotel_expert:demo').once();
  if (!demo || demo.success === false) throw new Error('Ошибка demo');
  console.log('Проверка успешно завершена.');
})().catch(error => { console.error(error); process.exitCode = 1; });
