// Необязательная проверка Prolog через Node.js и SWI-Prolog WebAssembly.
const fs = require('node:fs');
const path = require('node:path');
const local = path.join(__dirname, '.runtime/node_modules/swipl-wasm');
const shared = path.join(__dirname, '../.runtime/node_modules/swipl-wasm');
const SWIPL = require(fs.existsSync(local) ? local : shared);
(async () => {
  const pl = await SWIPL({ arguments: ['-q'] });
  for (const name of ['hotel_frames.pl', 'hotel_frames_tests.pl']) {
    pl.FS.writeFile('/' + name, fs.readFileSync(path.join(__dirname, name)));
  }
  function run(query) {
    const result = pl.prolog.query(query).once();
    if (!result || result.success === false) throw new Error('Failed: ' + query);
    return result;
  }
  run("consult('/hotel_frames_tests.pl')");
  run('run_tests');
  const { Count } = run("findall(N, plunit_hotel_frames:'unit test'(N,_,_,_), Ns), length(Ns, Count)");
  console.log(`Тестов пройдено: ${Count}`);
  run('hotel_frames:demo');
})().catch(error => { console.error(error); process.exitCode = 1; });
