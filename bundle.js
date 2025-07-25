import { bundle } from 'luabundle'
import * as fs from 'fs';

const bundledLua = bundle('./Profiler/Main.lua', {
    metadata: false,
    expressionHandler: (module, expression) => {
        const start = expression.loc.start
        console.warn(`WARNING: Non-literal require found in '${module.name}' at ${start.line}:${start.column}`)
    }
});

fs.writeFile('Profiler.lua', bundledLua, err => {
    if (err) {
        console.error('Error creating Profiler.lua:', err);
    } else {
        console.log('✅ Profiler library bundle created successfully -> Profiler.lua');
    }
});