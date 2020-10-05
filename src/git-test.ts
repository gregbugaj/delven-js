import ASTParser, { ErrorNode } from "./ASTParser"
import SourceGenerator from "./SourceGenerator";
import Utils from './util'
import * as fs from "fs"
import { resolve } from "path"
import fetch from 'node-fetch'

/**
 * Utility funcions for retrieving test data from teh esprima project
 * https://github.com/jquery/esprima/
 */
async function main() {
    const getData = async (url: string) => {
        const response = await fetch(url)
        const body = await response.text()
        const status = response.status
        return { status, body }
    }

    type GitData = {
        success: boolean,
        chunks: string[],
        code: string,
    }

    const getGitData = async (startChunk: string, url: string): Promise<GitData> => {
        const payload = await getData(url);
        const success = payload.status == 200 ? true : false
        const code = payload.body
        if (!success) {
            return { success: false, chunks: [], code: code }
        }

        const index = url.indexOf(startChunk);
        let s = url.slice(index)
        if (s.startsWith('/')) {
            s = s.slice(1)
        }
        s = s.slice(0, s.lastIndexOf('/'))
        const chunks = s.split('/')
        return { success, chunks, code }
    }

    //let iter = { *[Symbol.iterator]() {}}
    // const index = '0005';//.source
    //const name = `${index}`
    // const payload = await getGitData('/expression', `https://raw.githubusercontent.com/jquery/esprima/master/test/fixtures/ES6/method-definition/migrated_${index}.js`)
    
    const name = `migrated_0015`
    const payload = await getGitData('/statement', `https://raw.githubusercontent.com/jquery/esprima/master/test/fixtures/automatic-semicolon-insertion/${name}.js`)
    
    console.info(payload)
    if (!payload.success) {
        console.info("Gitdata returned with error")
        return;
    }

    const dir = resolve(__dirname, '../test/fixtures', ...payload.chunks)
    const code = payload.code
    const ast = ASTParser.parse({ type: "code", value: code });
    console.info(Utils.toJson(ast))

    if (ast instanceof ErrorNode) {
        console.info('Parse Errors')
        const jsFile = resolve(dir, `${name}.failure.js`)
        const jsonFile = resolve(dir, `${name}.failure.json`)
        /*         
                        if (fs.existsSync(jsFile)) {
                                throw new Error('File exists')
                        }
                        Utils.write(jsFile, code)
                        Utils.write(jsonFile, ast) */
        return;
    }

    const generator = new SourceGenerator();
    const script = generator.toSource(ast);
    console.info('-------')
    console.info(script)
    console.info('----------')
    console.info(code)
    const jsFile = resolve(dir, `${name}.js`)
    const jsonFile = resolve(dir, `${name}.tree.json`)

    if (fs.existsSync(jsFile) || fs.existsSync(jsonFile)) {
        throw new Error(`File already exists : ${jsFile}`)
    }

    Utils.write(jsFile, code)
    Utils.write(jsonFile, ast)
}

(async () => {
    await main()
})().catch(err => {
    console.error("error in main", err)
})

// Trick to prevent  > All files must be modules when the '--isolatedModules' flag is provided.ts(1208)
export { } 
