
//------------------------------------------------------------------------------
// Expression Bodies
// More expressive closure syntax.
// http://es6-features.org/#ExpressionBodies
//------------------------------------------------------------------------------

odds  = evens.map(v => v + 1)
pairs = evens.map(v => ({ even: v, odd: v + 1 }))
nums  = evens.map((v, i) => v + i)
