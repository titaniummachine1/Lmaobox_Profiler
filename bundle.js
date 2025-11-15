import { bundle } from 'luabundle'
import * as fs from 'fs';
import path from 'path';

const bundledLua = bundle('./Profiler/Main.lua', {
    metadata: false,
    expressionHandler: (module, expression) => {
        const start = expression.loc.start
        console.warn(`WARNING: Non-literal require found in '${module.name}' at ${start.line}:${start.column}`)
    }
});

const projectOutputPath = path.resolve('Profiler.lua');

try {
    fs.writeFileSync(projectOutputPath, bundledLua);
    console.log(`✅ Profiler library bundle created successfully -> ${projectOutputPath}`);
} catch (err) {
    console.error('Error creating Profiler.lua in project root:', err);
    process.exit(1);
}

const localAppData = process.env.LOCALAPPDATA;

if (!localAppData) {
    console.warn('⚠️  LOCALAPPDATA is not set; skipping deploy copy to %LOCALAPPDATA%/lua.');
    process.exit(0);
}

const luaDir = path.join(localAppData, 'lua');
const deployOutputPath = path.join(luaDir, 'Profiler.lua');

try {
    fs.mkdirSync(luaDir, { recursive: true });
    fs.writeFileSync(deployOutputPath, bundledLua);
    console.log(`✅ Profiler library copied to ${deployOutputPath}`);
} catch (err) {
    console.error(`Error copying Profiler.lua to '${deployOutputPath}':`, err);
    process.exit(1);
}