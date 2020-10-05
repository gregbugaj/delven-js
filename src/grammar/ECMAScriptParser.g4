/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 by Bart Kiers (original author) and Alexandre Vitorelli (contributor -> ported to CSharp)
 * Copyright (c) 2017-2020 by Ivan Kochurkin (Positive Technologies):
    added ECMAScript 6 support, cleared and transformed to the universal grammar.
 * Copyright (c) 2018 by Juan Alvarez (contributor -> ported to Go)
 * Copyright (c) 2019 by Student Main (contributor -> ES2020)
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * https://tc39.es/ecma262/
 * https://github.com/tc39/ecma262
 * https://www.ecma-international.org/ecma-262/11.0/index.html#title
 * https://kangax.github.io/nfe/  Named function expressions demystified
 */
parser grammar ECMAScriptParser;

options {
    tokenVocab=ECMAScriptLexer;
    superClass=ECMAScriptParserBase;
}

program
    : HashBangLine? sourceElements? EOF
    ;

sourceElement
    : statement
    ;

statement
 : block
 | querySelectStatement
 | variableStatement
 | importStatement
 | exportStatement
 | emptyStatement
 | classDeclaration
 | functionDeclaration // Footnote 7 Declaration switched to be be before the expressionStatement so function is detemined before the expression statement
 | expressionStatement
 | ifStatement
 | iterationStatement
 | continueStatement
 | breakStatement
 | returnStatement
 | withStatement
 | labelledStatement
 | switchStatement
 | throwStatement
 | tryStatement
 | debuggerStatement
 ;

block
 : '{' statementList? '}'
 ;

statementList
 : statement+
 ;

importStatement
    : Import importFromBlock
    ;

importFromBlock
    : StringLiteral eos  // GB : Footnote 10 > Switched order so we can handle `import "foo"`
    | importDefault ',' (importNamespace | moduleItems) importFrom eos
    | (importDefault ',')? (importNamespace | moduleItems) importFrom eos
    ;

moduleItems
    : '{' (aliasName ',')* (aliasName ','?)? '}'
    ;

importDefault
    : aliasName
    ;

importNamespace
    : ('*' | identifierName) (As identifierName)?
    ;

importFrom
    : From StringLiteral
    ;

aliasName
    : identifierName (As identifierName)?
    ;

exportStatement
    : Export (exportFromBlock | declaration) eos    # ExportDeclaration
    | Export Default (classDeclaration | functionDeclaration | singleExpression) eos           # ExportDefaultDeclaration  // GB Footnote 7
    ;

exportFromBlock
    : importNamespace importFrom eos
    | moduleItems importFrom? eos
    ;

declaration
    : variableStatement
    | classDeclaration
    | functionDeclaration
    ;

variableStatement
    : variableDeclarationList eos
    ;

variableDeclarationList
    : varModifier variableDeclaration (',' variableDeclaration)*
    ;

variableDeclaration
    : assignable ('=' singleExpression)? // ECMAScript 6: Array & Object Matching
//    | assignable ('='  query_expression)?
    ;

emptyStatement
 : SemiColon
 ;

expressionStatement
    : {this.notOpenBraceAndNotFunction()}? expressionSequence eos
    ;

ifStatement
 : If '(' expressionSequence ')' statement ( Else statement )?
 ;


iterationStatement
    : Do statement While '(' expressionSequence ')' eos                                                                       # DoStatement
    | While '(' expressionSequence ')' statement                                                                              # WhileStatement
    | For '(' (expressionSequence | variableDeclarationList)? ';' expressionSequence? ';' expressionSequence? ')' statement   # ForStatement
    | For '(' (singleExpression | variableDeclarationList) In expressionSequence ')' statement                                # ForInStatement
    // strange, 'of' is an identifier. and this.p("of") not work in sometime.
    | For Await? '(' (singleExpression | variableDeclarationList) identifier{this.p("of")}? expressionSequence ')' statement  # ForOfStatement
    ;

varModifier  // let, const - ECMAScript 6
    : Var
    | Let
    | Const
    ;

continueStatement
    : Continue ({this.notLineTerminator()}? identifier)? eos
    ;

breakStatement
    : Break ({this.notLineTerminator()}? identifier)? eos
    ;

returnStatement
    : Return ({this.notLineTerminator()}? expressionSequence)? eos
    ;

withStatement
    : With '(' expressionSequence ')' statement
    ;

switchStatement
    : Switch '(' expressionSequence ')' caseBlock
    ;

caseBlock
    : '{' caseClauses? (defaultClause caseClauses?)? '}'
    ;

caseClauses
 : caseClause+
 ;

caseClause
    : Case expressionSequence ':' statementList?
 ;

defaultClause
    : Default ':' statementList?
    ;

labelledStatement
    : identifier ':' statement
    ;

throwStatement
    : Throw {this.notLineTerminator()}? expressionSequence eos
    ;

tryStatement
    : Try block (catchProduction finallyProduction? | finallyProduction)
    ;

catchProduction
    : Catch ('(' assignable? ')')? block
    ;

finallyProduction
 : Finally block
 ;

debuggerStatement
 : Debugger eos
 ;

functionDeclaration
    : Async? Function '*'? identifier '(' formalParameterList? ')' '{' functionBody '}'
    ;   

classDeclaration
    : Class identifier classTail
    ;

classTail  // GB : Footnote 11
    : classHeritage?  '{' classElement* '}'
    ;

classHeritage
    : Extends singleExpression
    ;

classElement
    : (Static | {this.n("static")}? identifier | Async)* methodDefinition
    | emptyStatement
    | '#'? propertyName '=' singleExpression
    ;

methodDefinition
    : '*'? '#'? propertyName '(' formalParameterList? ')' '{' functionBody '}'
    | '*'? '#'? getter '(' ')' '{' functionBody '}'
    | '*'? '#'? setter '(' formalParameterList? ')' '{' functionBody '}'
    ;

// Issue#15
formalParameterList
    : formalParameterArg (',' formalParameterArg)* (',' lastFormalParameterArg?)?
    | lastFormalParameterArg
    ;

formalParameterArg
    : assignable ('=' singleExpression)?      // ECMAScript 6: Initialization
    ;

lastFormalParameterArg                        // ECMAScript 6: Rest Parameter
    : Ellipsis singleExpression
    ;

functionBody
 : sourceElements?
 ;
    
sourceElements
    : sourceElement+
    ;

arrayLiteral
    : ('[' elementList ']')
    ;

elementList
    : ','* arrayElement? (','+ arrayElement)* ','* // Yes, everything is optional
    ;

arrayElement
    : Ellipsis? singleExpression
    ;

propertyAssignment
    : propertyName ':' singleExpression                                             # PropertyExpressionAssignment
    | '[' singleExpression ']' ':' singleExpression                                 # ComputedPropertyExpressionAssignment // Footnote : This will never be used as `propertyName' has rule for [singleExpression]
    | Async? '*'? propertyName '(' formalParameterList?  ')'  '{' functionBody '}'  # FunctionProperty
    | getter '(' ')' '{' functionBody '}'                                           # PropertyGetter
    | setter '(' formalParameterArg ')' '{' functionBody '}'                        # PropertySetter
    | Ellipsis? singleExpression                                                    # PropertyShorthand
    ;

propertyName
    : identifierName
    | StringLiteral
    | numericLiteral
    | '[' singleExpression ']'
    ;

arguments
    : '('(argument (',' argument)* ','?)?')'
    ;


argument
    : Ellipsis? (singleExpression | identifier)
    ;
    
expressionSequence
 : singleExpression ( ',' singleExpression )*
 ;

singleExpression
    : anoymousFunction                                                      # FunctionExpression  // GB: footnote 5
    | Class identifier? classTail                                           # ClassExpression
    | singleExpression '[' expressionSequence ']'                           # MemberIndexExpression
    | New singleExpression '.' identifierName arguments                     # MemberNewExpression  // GB: Footnote 8
    | singleExpression '?'? '.' '#'? identifierName                         # MemberDotExpression
    | New singleExpression arguments                                        # NewExpression      // GB:footnote 4
    | New singleExpression arguments?                                       # NewExpression      // GB:footnote 4
    | New '.' identifier                                                    # MetaExpression     // new.target
    | singleExpression arguments                                            # ArgumentsExpression
    | singleExpression {this.notLineTerminator()}? '++'                     # PostIncrementExpression
    | singleExpression {this.notLineTerminator()}? '--'                     # PostDecreaseExpression
    | Delete singleExpression                                               # DeleteExpression
    | Void singleExpression                                                 # VoidExpression
    | Typeof singleExpression                                               # TypeofExpression
    | '++' singleExpression                                                 # PreIncrementExpression
    | '--' singleExpression                                                 # PreDecreaseExpression
    | '+' singleExpression                                                  # UnaryPlusExpression
    | '-' singleExpression                                                  # UnaryMinusExpression
    | '~' singleExpression                                                  # BitNotExpression
    | '!' singleExpression                                                  # NotExpression
    | Await singleExpression                                                # AwaitExpression
    | <assoc=right> singleExpression '**' singleExpression                  # PowerExpression
    | singleExpression ('*' | '/' | '%') singleExpression                   # MultiplicativeExpression
    | singleExpression ('+' | '-') singleExpression                         # AdditiveExpression
    | singleExpression '??' singleExpression                                # CoalesceExpression
    | singleExpression ('<<' | '>>' | '>>>') singleExpression               # BitShiftExpression
    | singleExpression ('<' | '>' | '<=' | '>=') singleExpression           # RelationalExpression
    | singleExpression Instanceof singleExpression                          # InstanceofExpression
    | singleExpression In singleExpression                                  # InExpression
    | singleExpression ('==' | '!=' | '===' | '!==') singleExpression       # EqualityExpression
    | singleExpression '&' singleExpression                                 # BitAndExpression
    | singleExpression '^' singleExpression                                 # BitXOrExpression
    | singleExpression '|' singleExpression                                 # BitOrExpression
    | singleExpression '&&' singleExpression                                # LogicalAndExpression
    | singleExpression '||' singleExpression                                # LogicalOrExpression
    | singleExpression '?' singleExpression ':' singleExpression            # TernaryExpression
    | <assoc=right> singleExpression '=' singleExpression                   # AssignmentExpression
    | <assoc=right> singleExpression assignmentOperator singleExpression    # AssignmentOperatorExpression
    | Import '(' singleExpression ')'                                       # ImportExpression
    | singleExpression TemplateStringLiteral                                # TemplateStringExpression  // ECMAScript 6
    | This                                                                  # ThisExpression
    | Yield ({this.notLineTerminator()}? ('*')? expressionSequence)?        # YieldExpression           // ECMAScript 6 : GB Footnote 1, 6
    | identifier                                                            # IdentifierExpression
    | Super                                                                 # SuperExpression
    | literal                                                               # LiteralExpression
    | arrayLiteral                                                          # ArrayLiteralExpression
    | objectLiteral                                                         # ObjectLiteralExpression
    | '(' expressionSequence ')'                                            # ParenthesizedExpression
    | queryExpression                                                       # InlinedQueryExpression
    ;

assignable
    : identifier
    | arrayLiteral
    | objectLiteral
    ;

objectLiteral
    : '{' (propertyAssignment (',' propertyAssignment)*)? ','? '}'
    ;

anoymousFunction
    : functionDeclaration                                                       # FunctionDecl
    | Async? Function '*'? '(' formalParameterList? ')' '{' functionBody '}'    # AnoymousFunctionDecl
    | Async? arrowFunctionParameters '=>' arrowFunctionBody                     # ArrowFunction
    ;

arrowFunctionParameters
    : identifier
    | '(' formalParameterList? ')'
    ;

arrowFunctionBody
    : '{' functionBody '}' 
    | singleExpression
    ;

/*// issue with `() => {}` resolving as object literal
arrowFunctionBody
  : singleExpression
  | '{' functionBody '}'
;*/

assignmentOperator
 : '*=' 
 | '/=' 
 | '%=' 
 | '+=' 
 | '-=' 
 | '<<=' 
 | '>>=' 
 | '>>>=' 
 | '&=' 
 | '^=' 
 | '|='
 | '**='
 ;

literal
    : NullLiteral
    | BooleanLiteral
    | StringLiteral
    | TemplateStringLiteral
    | RegularExpressionLiteral
    | numericLiteral
    | bigintLiteral
    ;

numericLiteral
    : DecimalLiteral
    | HexIntegerLiteral
    | OctalIntegerLiteral
    | OctalIntegerLiteral2
    | BinaryIntegerLiteral
    ;

bigintLiteral
    : BigDecimalIntegerLiteral
    | BigHexIntegerLiteral
    | BigOctalIntegerLiteral
    | BigBinaryIntegerLiteral
    ;

getter
    : {this.n("get")}? identifier propertyName
    ;

setter
    : {this.n("set")}? identifier propertyName
    ;

identifierName
 : Identifier
 | reservedWord
 ;

identifier
    : Identifier
    | NonStrictLet
    | Async
    ;

reservedWord
    : keyword
    | NullLiteral
    | BooleanLiteral
    ;

keyword
 : Break
 | Do
 | Instanceof
 | Typeof
 | Case
 | Else
 | New
 | Var
 | Catch
 | Finally
 | Return
 | Void
 | Continue
 | For
 | Switch
 | While
 | Debugger
 | Function
 | This
 | With
 | Default
 | If
 | Throw
 | Delete
 | In
 | Try
 | Class
 | Enum
 | Extends
 | Super
 | Const
 | Export
 | Import
 | Implements
 | Let
 | Private
 | Public
 | Interface
 | Package
 | Protected
 | Static
 | Yield
 | Async
 | Await
 | From
 | As
 ;

eos
    : SemiColon
    | EOF
    | {this.lineTerminatorAhead()}?
    | {this.closeBrace()}?
    ;

// Extension
// I like to name this properly to limit confusion
//https://stackoverflow.com/questions/34131071/sql-clause-vs-expression-terms
querySelectStatement
  : queryExpression
  ;

queryExpression
  :  (querySpecification | '(' queryExpression ')') sql_union*
  ;

sql_union
  : (Union All?) (querySpecification | ('(' queryExpression ')'))                                    # QueryUnionExpression
  ;

querySpecification
  : bind_clause? Select select_list
    withinClause? fromClause? whereClause? produce_clause?                                          # QuerySelectExpression // This shoudl producte Node.QueryExpression
  ;

select_list
  : select_list_elem (',' select_list_elem)*                                                        # QuerySelectListExpression
  ;

select_list_elem
  : '*'
  | identifier (As identifierName)?
  | singleExpression argument (As identifierName)?
	;

fromClause
	: From dataSources                                                                                # QueryFromExpression
  ;

whereClause
  : Where expressionSequence                                                                        # QueryWhereExpression
  ;

dataSources
  : dataSource (',' dataSource)*                                                                    # QueryDataSourcesExpression
  ;

dataSource
  : data_source_item_joined
  | '(' data_source_item_joined ')'
  ;

data_source_item_joined
  : data_source_item using_source_clause? join_clause*                                               # QueryDataSourceExpression
  ;

data_source_item
  : Url                                                                                             # QueryDataSourceItemUrlExpression
  | singleExpression arguments                                                                      # QueryDataSourceItemArgumentsExpression
  | identifier                                                                                      # QueryDataSourceItemIdentifierExpression
  | '(' queryExpression ')'                                                                         # QueryDataSourceItemSubqueryExpression
    //| anoymousFunction
    //| arrayLiteral
//  | Url
  ;

join_clause
  : Join dataSources                                                                                # QueryJoinCrossApplyExpression // This should be equivalent to SQL Cross Apply
  | Join dataSources On singleExpression ('==' | '===') singleExpression                            # QueryJoinOnExpression // only support for equijoin
//    | Join data_source using_clause                                          # QueryJoinUsingExpression // Combiner
  ;

using_source_clause
  : Using queryObjectLiteral                                                                        # QuerySourceUsingLiteralExpression
  | Using singleExpression                                                                          # QuerySourceUsingSingleExpression
  ;

produce_clause
  : Produce singleExpression                                                                        # QueryProduceExpression
  ;

bind_clause
  : Using singleExpression                                                                          # QueryBindExpression
  ;

withinClause
  : Within singleExpression (',' singleExpression)*                                                 # QueryWithinExpression
  ;

queryObjectLiteral
  : '{' (queryPropertyAssignment (',' queryPropertyAssignment)*)? ','? '}'
  ;

queryPropertyAssignment
  : propertyName ':' singleExpression
  ;
