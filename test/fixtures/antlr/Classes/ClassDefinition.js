
//------------------------------------------------------------------------------
// Class Definition
// More intuitive, OOP-style and boilerplate-free classes.
// http://es6-features.org/#ClassDefinition
//------------------------------------------------------------------------------

class Shape {
    constructor (id, x, y) {
        this.id = id
        this.move(x, y)
    }
    move (x, y) {
        this.x = x
        this.y = y
    }
}
