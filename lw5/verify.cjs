// Необязательный запуск через SWI-Prolog WebAssembly при наличии Node.js.
const fs = require('node:fs');
const path = require('node:path');
const local = path.join(__dirname, '.runtime/node_modules/swipl-wasm');
const shared = path.join(__dirname, '../.runtime/node_modules/swipl-wasm');
const SWIPL = require(fs.existsSync(local) ? local : shared);
(async () => {
  const pl = await SWIPL({ arguments: ['-q'] });
  for (const name of ['hotel_bayes.pl', 'hotel_bayes_tests.pl']) {
    pl.FS.writeFile('/' + name, fs.readFileSync(path.join(__dirname, name)));
  }
  function run(query) {
    const result = pl.prolog.query(query).once();
    if (!result || result.success === false) throw new Error('Failed: ' + query);
    return result;
  }
  run("consult('/hotel_bayes_tests.pl')");
  run('run_tests');
  const { Count } = run("findall(N, plunit_hotel_bayes:'unit test'(N,_,_,_), Ns), length(Ns, Count)");
  console.log(`Тестов пройдено: ${Count}`);
  run('hotel_bayes:demo');
})().catch(error => { console.error(error); process.exitCode = 1; });
