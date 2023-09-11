const consoleLog = (ptr, len) => {
    console.log(readCharStr(ptr, len));
}

const performanceNow = () => {
    return performance.now();
}

const dateNow = () => {
    return Date.now();
}

const readCharStr = (ptr, len) => {
    const array = new Uint8Array(memory.buffer, ptr, len)
    const decoder = new TextDecoder()
    return decoder.decode(array)
}

let log_string = '';

const wasm_log_write = (ptr, len) => {
    log_string += readCharStr(ptr, len)
}

const wasm_log_flush = () => {
    console.log(log_string)
    log_string = ''
}

const download = (filenamePtr, filenameLen, mimetypePtr, mimetypeLen, dataPtr, dataLen) => {
    const a = document.createElement('a');
    a.style = 'display:none';
    document.body.appendChild(a);
    const view = new Uint8Array(memory.buffer, dataPtr, dataLen);
    const mimetype = readCharStr(mimetypePtr, mimetypeLen);
    const blob = new Blob([view], {
        type: mimetype
    });
    const url = window.URL.createObjectURL(blob);
    a.href = url;
    const filename = readCharStr(filenamePtr, filenameLen);
    a.download = filename;
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
}


const fmodf = (x, y) => x % y;
const sinf = Math.sin;
const cosf = Math.cos;
const roundf = Math.round;
const fabs = Math.abs;
const abs = Math.abs;
const sqrt = Math.sqrt;
const expf = Math.exp;
const pow = Math.pow;
const ceil = Math.ceil;
const ldexp = (x, exp) => x * Math.pow(2, exp);

export {
    consoleLog,
    wasm_log_write,
    wasm_log_flush,
    performanceNow,
    dateNow,
    download,
    readCharStr,
    fmodf,
    sinf,
    cosf,
    roundf,
    fabs,
    abs,
    sqrt,
    expf,
    pow,
    ceil,
    ldexp,
}