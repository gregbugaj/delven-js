# delven-js


ECMAScript parser written in TypeScript using ANTL(EBNF) for grammar and lexer generation that generates ESTree-compatible AST.

## Features 

- Fully supported ECMAScript 2020
- ESTree Spec compliant
- Well tested ~1000 unit tests

## Installation

```bash
npm install --save delven-js
```

### Example usage 

```javascript
    import ASTParser from "./ASTParser"

    const code = `let x = ()=> {1}`
    const ast = ASTParser.parse({ type: "code", value: code });
    console.info(JSON.stringify(ast))
```

Output

```json
{
    "type": "Program",
    "body": [
        {
            "type": "VariableDeclaration",
            "declarations": [
                {
                    "type": "VariableDeclarator",
                    "id": {
                        "type": "Identifier",
                        "name": "x"
                    },
                    "init": {
                        "type": "ArrowFunctionExpression",
                        "id": null,
                        "params": [],
                        "body": {
                            "type": "Literal",
                            "value": 1,
                            "raw": "1",
                            "start": 0,
                            "end": 0
                        },
                        "generator": false,
                        "expression": true,
                        "async": false
                    }
                }
            ],
            "kind": "let"
        }
    ],
    "sourceType": "module",
    "start": 0,
    "end": 0
}

```


## API


## Development Setup

Notes on why certain thing have been done and how they has been overcomed. 

```bash
nvm cache clear
nvm install v14.5.0
nvm use v14.5.0

npm install
```

## Start publishing changes 

```bash
 npx babel --watch src --out-dir dist --extensions '.ts'  --source-maps inline
 antlr4 -Dlanguage=JavaScript *.g4 -o ../parser -visitor -no-listener
```

## Run ESLint 

```bash
npx eslint ./src/
```

## Run

[Enable / Disable trace warnings](https://www.xiaoru.li/post/disabling-node-warnings/)
`Warning: Accessing non-existent property 'INVALID_ALT_NUMBER' of module exports inside circular dependency`

```bash
node --trace-warnings ./dist/index
node --no-warnings  ./dist/index
```


### Grammars

ANTL grammar based on the official [ANTL4 ecma/javascript grammar](https://github.com/antlr/grammars-v4/tree/master/javascript)

This build includes fixes to both grammars and ANTL javascript runtimes.

## Footnotes

Grammar is annotated with footnotes that descbe why it diverged from the main. Pull reuqest are in place to have them merged into main.

### 1 Grammar causing infinive loop

See #6

footnone :
Fix null check in ./node_modules/antlr4/Utils.js


### 3. Order swapped for NewExpression and ArgumentsExpression

This is necessary so the expression in form will be evaluated as `NewExpression` with 3 nodes(NEW singleExpression arguments?) and not as `NewExpression` with 2 nodes(NEW singleExpression) where `singleExpression` is a `ArgumentsExpression` node.

```javascript
let x = new z(...k)
```

### 4 `New` not resolving properly

```ebnf
    | New singleExpression arguments?                                       # NewExpression      // GB:footnote 4
    | New '.' identifier                                                    # MetaExpression // new.target
    | singleExpression arguments                                            # ArgumentsExpression
```

### 5.  Arrow function 

Issue  with `() => {}` resolving as object literal while it should have been an `arrow function` with empty `BlockStatement`


### 6. Yield  : YieldExpression

There are two issues with `YieldStatement`

1) Inifnitive loop causing  stackoverflow.
2) Not properly handling generator functions `yield *fun()`

Issue #1 was fixed by removing 'eos' from original rule.
Issue #2 was fixed by adding support to handle `Yield` with generatators. 
Broke down declaration into two separate rules, order here is important as the yield start will get evaluated
as `MuliplicativeExpression` due to `singleExpression` being produced by `expressionSequence`

Original EBNF

```ebnf
yieldExpression
    : Yield ({this.notLineTerminator()}? expressionSequence)? eos
```

Updated EBNF

```ebnf
yieldDeclaration
    : Yield {this.notLineTerminator()} ('*')? expressionSequence
    | Yield eos
    ;
```

Reference : 
[https://tc39.es/ecma262/#prod-YieldExpression]
[https://tc39.es/ecma262/#sec-generator-function-definitions-runtime-semantics-evaluation]


### 7. Export Declaration evaluating Funcion and Class Declarations as Expressions

In original grammar `singleExpression` evaluates `export default function (){}` as  `ExportDefaultDeclaration > FunctionExpression` instead of an `ExportDefaultDeclaration > FunctionDeclaration`. This same thing goes for Class `export default class{}`

Original EBNF

```ebnf
exportStatement
    : Export (exportFromBlock | declaration) eos    # ExportDeclaration
    | Export Default singleExpression eos           # ExportDefaultDeclaration  // GB Footnote 7
    ;
```

Updated EBNF

```ebnf
exportStatement
    : Export (exportFromBlock | declaration) eos    # ExportDeclaration
    | Export Default (classDeclaration | functionDeclaration | singleExpression) eos           # ExportDefaultDeclaration  // GB Footnote 7
    ;
```

### 8. Left-Hand-Side Expressions not resolving correctly

There are two primary issues here.

First there is an incomplete rule

There is an incomplete definition for the grammar that down not handle spec `new MemberExpression[?Yield, ?Await] Arguments[?Yield, ?Await]` this causes the rule to fall through and be handled by `NewExpression`

To solve this we added following alternative rule `MemberNewExpression`

```ebnf
  New singleExpression '.' identifierName arguments                     # MemberNewExpression  // GB: Footnote 8
```

Property generated AST needs to look as follows

```javascript
new foo             // NewExpression[Type = Identifier]
new foo()           // NewExpression[Type = Identifier]

new foo.bar()       // NewExpression[Type = MemberExpression]
new foo.bar         // NewExpression[Type = MemberExpression]
new foo.bar.zet()   // NewExpression[Type = MemberExpression] > MemberExpression

new foo().bar(a)    // CallExpression[Type = MemberExpression] > NewExpression[Type = Identifier]
new foo[1].bar(a)   // NewExpression[Type = MemberExpression]

new {}.test()       // NewExpression[type=MemberExpression] > ObjectExpression
new {}().test()     // CallExpression[type=MemberExpression] > NewExpression > ObjectExpression
```

AST should be equivalent for all the expressions

```javascript
new {}
new {}() 

new []
new []()

new foo
new foo()

new foo.bar
new foo.bar()
```

Second issue is that the `MemberXXXExpression` rules need to be pulled up to be resolved before `NewExpression` rules to make sure that they resolved in proper order as per spec [https://tc39.es/ecma262/#prod-MemberExpression]

```ebnf
NewExpression[Yield, Await]:
    MemberExpression[?Yield, ?Await]
    new NewExpression[?Yield, ?Await]
```

Long term solution here is to break appart `singleExpression` to make make clear distintion between `MemberExpression` and `NewExpression`
In interum we add just adding additional `MemberXXXExpression` expressions to `singleExpression`

### 11. Changed grammar to be closer to the specification

There is nothing wrong with existing grammar but this makes it simpler and follows the naming from the specification

```ebnf
classTail  // GB : Footnote 11
    : classHeritage?  '{' classElement* '}'
    ;

classHeritage
    : Extends singleExpression
    ;
```

[ClassBody](https://tc39.es/ecma262/#prod-ClassBody)

## ERRORS

https://github.com/antlr/grammars-v4/pull/1553
https://github.com/antlr/grammars-v4/issues/1580

RangeError: Maximum call stack size exceeded
    at Hash.update (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/Utils.js:338:34)
    at Hash.update (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/Utils.js:344:25)
    at AND.updateHashCode (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/SemanticContext.js:245:10)
    at Hash.update (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/Utils.js:360:31)
    at ATNConfig.hashCodeForConfigSet (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/ATNConfig.js:110:10)
    at Set.hashATNConfig [as hashFunction] (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/ATNConfigSet.js:21:11)
    at Set.add (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/Utils.js:96:21)
    at ATNConfigSet.add (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/ATNConfigSet.js:99:35)
    at ParserATNSimulator.closure_ (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1263:17)
    at ParserATNSimulator.closureCheckingStopState (/home/gbugaj/devio/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1254:10)



Causes ERROR ::

```JavaScript
class x extends y { }
class x extends function() {} {}
class x extends class x {} {} {}
```
---------------------

/home/greg/dev/delven.io/delven-transpiler/dist/parser/ECMAScriptParser.js:1038
	    	throw re;
	    	^

RangeError: Maximum call stack size exceeded
    at ParserATNSimulator.canDropLoopEntryEdgeInLeftRecursiveRule (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1316:80)
    at ParserATNSimulator.closure_ (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1268:25)
    at ParserATNSimulator.closureCheckingStopState (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1254:10)
    at ParserATNSimulator.closure_ (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1310:18)
    at ParserATNSimulator.closureCheckingStopState (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1254:10)
    at ParserATNSimulator.closure_ (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1310:18)
    at ParserATNSimulator.closureCheckingStopState (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1254:10)
    at ParserATNSimulator.closure_ (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1310:18)
    at ParserATNSimulator.closureCheckingStopState (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1254:10)
    at ParserATNSimulator.closure_ (/home/greg/dev/delven.io/delven-transpiler/node_modules/antlr4/atn/ParserATNSimulator.js:1310:18)
