/* -*- C++  LALR1 Parser specification -*- */
%skeleton "lalr1.cc"
%require "3.0.4"
%defines
%define parser_class_name {mm_parser};

/* Generate token constructors */
%define api.token.constructor;

/* Use C++ variant semantic values */
%define api.value.type variant;
%define parse.assert;

/* Expect only 1 shift/reduce conflict on "else" token. */
%expect 1;

%code requires {
#include <string>
#include "types.h"
#include "symbols.h"
#include "expressions.h"

  class mm_translator;
 }

/* A translator object is used to construct its parser. */
%param {mm_translator &translator};

%code {
  /* Include translator definitions completely */
#include "ass4_15CS30035_translator.h"
  
  /* Helper functions to get dereferenced symbols for scalars
   * Only used when Expression is known to be non-matrix type. */
  SymbolRef
    getScalarBinaryOperand(mm_translator & ,
			   yy::mm_parser & ,
			   const yy::location & ,
			   Expression & );
  SymbolRef
    getIntegerBinaryOperand(mm_translator & ,
			    yy::mm_parser & ,
			    const yy::location & ,
			    Expression & );

  /* Checks if the given symbol has type equal to given type on not.
     If not, then converts / throws accordingly. */
  SymbolRef typeCheck(SymbolRef, // symbol
		      DataType &,// type
		      bool, // convert?
		      mm_translator &,
		      yy::mm_parser &,
		      const yy::location & );

  /* Emits opcodes for performing a scalar binary operation */
  void emitScalarBinaryOperation(char ,
				 mm_translator &,
				 yy::mm_parser &,
				 Expression & ,
				 Expression & ,
				 Expression & ,
				 const yy::location &,
				 const yy::location &,
				 const yy::location & );

  /* For bitwise / modulo operations */
  void emitIntegerBinaryOperation(char ,
				  mm_translator &,
				  yy::mm_parser &,
				  Expression &,
				  Expression &,
				  Expression &,
				  const yy::location &,
				  const yy::location &,
				  const yy::location & );
  
  /* For comparison operations */
  void emitConditionOperation(char ,
			      mm_translator &,
			      yy::mm_parser &,
			      Expression &,
			      Expression &,
			      Expression &,
			      const yy::location &,
			      const yy::location &,
			      const yy::location & );
 }

/* Enable bison location tracking */
%locations;

/* Initialize the parser location to the new file */
%initial-action{
  @$.initialize( &translator.file );
 }

/* Enable verobse parse tracing */
%define parse.trace;
%define parse.error verbose;

/* Prefix all token constants with TOK_ */
%define api.token.prefix {TOK_};


/**************************************************/
/**********Begin token definitions*****************/
%token
END 0 "EOF"
MM_IF "if"
MM_ELSE "else"
MM_DO "do"
MM_WHILE "while"
MM_FOR "for"
MM_RETURN "return"
MM_VOID "void"
MM_CHAR "char"
MM_INT "int"
MM_DOUBLE "double"
MM_MATRIX "Matrix"

LBRACE "{"
RBRACE "}"
LBOX "["
RBOX "]"
LBRACKET "("
RBRACKET ")"

INC "++"
DEC "--"
SHL "<<"
SHR ">>"
AND "&&"
OR "||"
TRANSPOSE ".'"

AMPERSAND "&"
CARET "^"
BAR "|"
NOT "!"

STAR "*"
PLUS "+"
MINUS "-"
SLASH "/"
TILDE "~"
PERCENT "%"
ASSGN "="

LT "<"
GT ">"
LTE "<="
GTE ">="
EQUAL "=="
NEQ "!="

QMARK "?"
COLON ":"
SEMICOLON ";"
COMMA ","
;

%token <std::string> IDENTIFIER STRING_LITERAL ;
%token <char> CHARACTER_CONSTANT ;

/* Only 32-bit signed integer is supported for now */
%token <int> INTEGER_CONSTANT ;

/* All float-point arithmetic is in double precision only */
%token <double> FLOATING_CONSTANT ;

/************End token definitions*****************/
/**************************************************/



/* Parse debugger */
%printer { yyoutput << $$ ; } <int> ;
%printer { yyoutput << $$ ; } <double> ;
%printer { yyoutput << $$ ; } <std::string> ;

%%

/**********************************************************************/
/*********************EXPRESSION NON-TERMINALS*************************/
/**********************************************************************/

%type <Expression> primary_expression;
primary_expression :
IDENTIFIER {
  int scope = translator.currentEnvironment();
  bool found = false;
  for( ; scope != 0 ; scope = translator.tables[scope].parent ) {
    try {
      $$.symbol.second = translator.tables[scope].lookup($1);
      $$.symbol.first = scope;
      found = true;
    } catch ( ... ) {
    }
  }
  try {
    $$.symbol.second = translator.tables[0].lookup($1);
    $$.symbol.first = scope;
    found = true;
  } catch ( ... ) {
  }
  if(not found) {
    throw syntax_error(@$ , "Identifier :"+$1+" not declared in scope.") ;
  }
  $$.auxSymbol = $$.symbol;
  $$.isReference = true;
}
|
INTEGER_CONSTANT {
  DataType intType = MM_INT_TYPE;
  SymbolRef ref = translator.genTemp(intType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.intVal = $1;
  temp.isInitialized = true;
  temp.isConstant = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
FLOATING_CONSTANT {
  DataType doubleType = MM_DOUBLE_TYPE;
  SymbolRef ref = translator.genTemp(doubleType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.doubleVal = $1;
  temp.isInitialized = true;
  temp.isConstant = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));
}
|
CHARACTER_CONSTANT {
  DataType charType = MM_CHAR_TYPE;
  SymbolRef ref = translator.genTemp(charType);
  Symbol & temp = translator.getSymbol(ref);
  temp.value.charVal = $1;
  temp.isInitialized = true;
  temp.isConstant = true;
  $$.symbol = ref;
  translator.emit(Taco(OP_COPY,temp.id,std::to_string($1)));  
}
|
STRING_LITERAL {
  DataType charPointerType = MM_CHAR_TYPE;
  charPointerType.pointers++;
  SymbolRef ref = translator.genTemp(charPointerType);
  Symbol & temp = translator.getSymbol(ref);
  $$.symbol = ref;
}
|
"(" expression ")" {
  std::swap($$,$2);
}
;

%type <Expression> postfix_expression;
postfix_expression:
primary_expression {
  std::swap($$,$1);
}
|
/* Store element offset. Turn on reference flag.
    Empty expressions not allowed, exactly two indices are required. */
postfix_expression "[" expression "]" "[" expression "]" {
  
  if( translator.isMatrixReference($1) ) {
    throw syntax_error(@1,"Syntax error.");
  }
  
  Symbol & lSym = translator.getSymbol($1.symbol);
  std::swap($$,$1);
  if( lSym.type.isStaticMatrix() ) {// simple matricks
    DataType addressType = MM_INT_TYPE;
    SymbolRef tempRef = translator.genTemp(addressType);
    Symbol & temp = translator.getSymbol(tempRef);
    Symbol & LHS = translator.getSymbol($$.symbol);
    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + LHS.id + "." );
    }
    translator.emit(Taco(OP_MULT,temp.id,rowIndex.id,std::to_string(LHS.type.cols)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,colIndex.id));
    translator.emit(Taco(OP_MULT,temp.id,temp.id,std::to_string(SIZE_OF_DOUBLE)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,std::to_string(2*SIZE_OF_INT)));
    $$.auxSymbol = tempRef;
    $$.isReference = true;
  } else if( lSym.type.isMatrix() ) {
    DataType addressType = MM_INT_TYPE;
    SymbolRef tempRef = translator.genTemp(addressType);
    Symbol & temp = translator.getSymbol(tempRef);
    Symbol & LHS = translator.getSymbol($$.symbol);
    Symbol & rowIndex = translator.getSymbol($3.symbol);
    Symbol & colIndex = translator.getSymbol($6.symbol);
    if( rowIndex.type != MM_INT_TYPE or colIndex.type != MM_INT_TYPE ) {
      throw syntax_error(@$ , "Non-integral index for matrix " + LHS.id + "." );
    }
    translator.emit(Taco(OP_RXC,temp.id,LHS.id, std::to_string(SIZE_OF_INT) ));//t = m[4] (# of columns)
    translator.emit(Taco(OP_MULT,temp.id,rowIndex.id,temp.id));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,colIndex.id));
    translator.emit(Taco(OP_MULT,temp.id,temp.id,std::to_string(SIZE_OF_DOUBLE)));
    translator.emit(Taco(OP_PLUS,temp.id,temp.id,std::to_string(2*SIZE_OF_INT)));
    $$.auxSymbol = tempRef;
    $$.isReference = true;
  } else {
    throw syntax_error(@$ , "Invalid type for subscripting.");
  }

}
|
/* Function call */
postfix_expression "(" optional_argument_list ")" {
  throw syntax_error(@$,"TODO.");
}
|
postfix_expression inc_dec_op { // inc_dec_op generates ++ or --
  std::swap($$,$1);
  DataType baseType = translator.getSymbol($$.symbol).type;
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      if(baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE) {// basic types
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & LHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,ret.id,LHS.id));// value before incrementation / decrementation
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,LHS.id,LHS.id,"1"));
	else translator.emit(Taco(OP_MINUS,LHS.id,LHS.id,"1"));
	$$.symbol = retRef;
      } else if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & LHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,ret.id,LHS.id));// value before incrementation / decrementation
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,LHS.id,LHS.id,std::to_string(elementType.getSize())));
	else translator.emit(Taco(OP_MINUS,LHS.id,LHS.id,std::to_string(elementType.getSize())));
	$$.symbol = retRef;
      } else {// matrix or other types
	throw syntax_error(@1,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {// matrix element
      DataType returnType = MM_DOUBLE_TYPE;
      SymbolRef retRef = translator.genTemp(returnType);
      SymbolRef newRef = translator.genTemp(returnType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      Symbol & LHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,LHS.id,auxSymbol.id));// ret = m[off]
      Symbol & newSymbol = translator.getSymbol(newRef);
      if( $2 == '+' ) translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// temp = ret+1
      else translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// temp = ret-1
      translator.emit(Taco(OP_LXC,LHS.id,auxSymbol.id,newSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else if( translator.isPointerReference($$) ) {
      SymbolRef newRef = translator.genTemp(baseType);
      Symbol & newSymbol = translator.getSymbol(newRef);// stores new value
      Symbol & retSymbol = translator.getSymbol($$.symbol);// return value
      Symbol & pointerId = translator.getSymbol($$.auxSymbol);// pointer id
      if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	if( $2 == '+' )
	  translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// new = ret+sz
	else
	  translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// new = ret-sz
      } else if( baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE ) {// basic types
	if( $2 == '+' ) translator.emit(Taco(OP_PLUS,newSymbol.id,retSymbol.id,"1"));// new = ret+1
	else translator.emit(Taco(OP_MINUS,newSymbol.id,retSymbol.id,"1"));// new = ret-1
      } else {
	throw syntax_error(@1 , "Invalid operand.");
      }
      translator.emit(Taco(OP_L_DEREF,pointerId.id,newSymbol.id));//copy back : *ptr = new
    } else {
      throw syntax_error(@1,"Invalid operand.");
    }
    $$.isReference = false;
  } else {
    throw syntax_error(@1,"Invalid operand.");
  }
}
|
postfix_expression ".'" {
  /* TODO : Support matrix transposition */
  throw syntax_error(@$, "Matrix transpose not supported yet.");
}
;

%type <char> inc_dec_op;
inc_dec_op : "++" { $$ = '+'; } | "--" { $$ = '-'; } ;

%type < std::vector<Expression> > optional_argument_list argument_list;
optional_argument_list : %empty { } | argument_list { std::swap($$,$1); } ;
argument_list : expression { $$.push_back($1); } | argument_list "," expression { swap($$,$1); $$.push_back($3); } ;

%type <Expression> unary_expression;
unary_expression : postfix_expression { std::swap($$,$1); } // copy
|
inc_dec_op unary_expression { // prefix increment operator
  std::swap($$,$2);
  DataType baseType = translator.getSymbol($$.symbol).type;
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      if(baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE) {// basic types
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,ret.id,RHS.id,"1"));
	else translator.emit(Taco(OP_MINUS,ret.id,RHS.id,"1"));
	translator.emit(Taco(OP_COPY,RHS.id,ret.id));// value after incrementation / decrementation
	$$.symbol = retRef;
      } else if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	SymbolRef retRef = translator.genTemp(baseType);
	Symbol & ret = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,ret.id,RHS.id,std::to_string(elementType.getSize())));
	else translator.emit(Taco(OP_MINUS,ret.id,RHS.id,std::to_string(elementType.getSize())));
	translator.emit(Taco(OP_COPY,RHS.id,ret.id));// value before incrementation / decrementation
	$$.symbol = retRef;
      } else {// matrix or other types
	throw syntax_error(@2,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {// matrix element
      DataType returnType = MM_DOUBLE_TYPE;
      SymbolRef retRef = translator.genTemp(returnType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
      Symbol & RHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
      if( $1 == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,"1"));// ret = ret+1
      else translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,"1"));// ret = ret-1
      translator.emit(Taco(OP_LXC,RHS.id,auxSymbol.id,retSymbol.id));//copy back : m[off] = temp
      $$.symbol = retRef;
      $$.isReference = false;
    } else if( translator.isPointerReference($$) ) {
      Symbol & retSymbol = translator.getSymbol($$.symbol);// return value
      Symbol & pointerId = translator.getSymbol($$.auxSymbol);// pointer id
      if( baseType.isPointer() ) {
	DataType elementType = baseType; elementType.pointers--;
	if( $1 == '+' )
	  translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// ret = ret+sz
	else
	  translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,std::to_string(elementType.getSize())));// ret = ret-sz
      } else if( baseType == MM_CHAR_TYPE or baseType == MM_INT_TYPE or baseType == MM_DOUBLE_TYPE ) {// basic types
	if( $1 == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,retSymbol.id,"1"));// ret = ret+1
	else translator.emit(Taco(OP_MINUS,retSymbol.id,retSymbol.id,"1"));// ret = ret-1
      } else {
	throw syntax_error(@2 , "Invalid operand.");
      }
      translator.emit(Taco(OP_L_DEREF,pointerId.id,retSymbol.id));//copy back : *ptr = new
    } else {
      throw syntax_error(@1,"Invalid operand.");
    }
    $$.isReference = false;
  } else {
    throw syntax_error(@1,"Invalid operand.");
  }
  
}
|
unary_operator unary_expression {
  std::swap($$,$2);// copy all
  DataType rType = translator.getSymbol($$.symbol).type;
  switch($1) {
  case '&' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) { // just take reference
	if( rType.isMatrix() ) {
	  throw syntax_error(@2,"Invalid matrix operand.");
	}
	DataType pointerType = rType; pointerType.pointers++;
	SymbolRef retRef = translator.genTemp(pointerType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_REFER,retSymbol.id,RHS.id));
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType pointerType = MM_DOUBLE_TYPE; pointerType.pointers++;
	SymbolRef retRef = translator.genTemp(pointerType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_PLUS,retSymbol.id,RHS.id,auxSymbol.id));// base + offset
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {
	$$.symbol = $$.auxSymbol; // take back pointer
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
    } else {
      throw syntax_error(@$,"Attempting to take reference of non-l-value.");
    }
    $$.isReference = false;
  } break;
    
  case '*' : {
    if( rType.isPointer() ) {
      DataType elementType = rType; elementType.pointers--;
      SymbolRef retRef = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(retRef);
      Symbol & RHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_R_DEREF,retSymbol.id,RHS.id));
      $$.auxSymbol = $$.symbol;
      $$.symbol = retRef;
      $$.isReference = true;
    } else {
      throw syntax_error(@$,"Attempting to dereference non-pointer type.");
    }
  } break;
    
  case '+' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) {
	if( rType.isMatrix() ) {// Dynoge
	  throw syntax_error(@$,"Matrix operations not supported yet.");
	}
	SymbolRef retRef = translator.genTemp(rType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,retSymbol.id,RHS.id));
	if( RHS.isInitialized ) {
	  retSymbol.isInitialized = true;
	  if( rType == MM_CHAR_TYPE ) retSymbol.value.charVal = RHS.value.charVal;
	  else if( rType == MM_INT_TYPE ) retSymbol.value.intVal = RHS.value.intVal;
	  else if( rType == MM_DOUBLE_TYPE ) retSymbol.value.doubleVal = RHS.value.doubleVal;
	}
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {//for pointer reference, just lower flag
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
      $$.isReference = false;
    } else {
      if( rType == MM_VOID_TYPE ) { // allow any rvalue except void type
	throw syntax_error(@2,"Invalid operand.");
      }
    }
  } break;
    
  case '-' : {
    if( $$.isReference ) {
      if( translator.isSimpleReference($$) ) {
	if( rType.isMatrix() ) {// Dynoge
	  throw syntax_error(@$,"Matrix operations not supported yet.");
	}
	SymbolRef retRef = translator.genTemp(rType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & RHS = translator.getSymbol($$.symbol);
	if( RHS.isInitialized ) {
	  retSymbol.isInitialized = true;
	  if( rType == MM_CHAR_TYPE ) retSymbol.value.charVal = -RHS.value.charVal;
	  else if( rType == MM_INT_TYPE ) retSymbol.value.intVal = -RHS.value.intVal;
	  else if( rType == MM_DOUBLE_TYPE ) retSymbol.value.doubleVal = -RHS.value.doubleVal;
	}
	translator.emit(Taco(OP_UMINUS,retSymbol.id,RHS.id));
	$$.symbol = retRef;
      } else if( translator.isMatrixReference($$) ) {
	DataType elementType = MM_DOUBLE_TYPE;
	SymbolRef retRef = translator.genTemp(elementType);
	Symbol & retSymbol = translator.getSymbol(retRef);
	Symbol & auxSymbol = translator.getSymbol($$.auxSymbol);
	Symbol & RHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_RXC,retSymbol.id,RHS.id,auxSymbol.id));// ret = m[off]
	$$.symbol = retRef;
      } else if( translator.isPointerReference($$) ) {
	throw syntax_error(@$ , "Unary minus on pointer not allowed." );
      } else {
	throw syntax_error(@2,"Invalid operand.");
      }
      Symbol & retSymbol = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_UMINUS,retSymbol.id,retSymbol.id));
      $$.isReference = false;
    } else if( rType.isPointer() ) {
      throw syntax_error(@$ , "Unary minus on pointer not allowed." );
    } else {
      if( rType.isMatrix() ) {// Dynoge
	throw syntax_error(@$,"Matrix operations not supported yet.");
      }
      Symbol & RHS = translator.getSymbol($$.symbol);
      translator.emit(Taco(OP_UMINUS,RHS.id,RHS.id));//
      if( RHS.isInitialized ) {
	if( rType == MM_CHAR_TYPE ) RHS.value.charVal = -RHS.value.charVal;
	else if( rType == MM_INT_TYPE ) RHS.value.intVal = -RHS.value.intVal;
	else if( rType == MM_DOUBLE_TYPE ) RHS.value.doubleVal = -RHS.value.doubleVal;
      }
    }
  } break;
    
  case '~' : {
    SymbolRef RHR = getIntegerBinaryOperand(translator,*this,@2,$$);
    SymbolRef retRef ;
    Symbol & RHS = translator.getSymbol(RHR);
    if( translator.isTemporary(RHR) ) retRef = RHR;
    else retRef = translator.genTemp(RHS.type);
    Symbol & retSym = translator.getSymbol(retRef);
    Symbol & CRHS = translator.getSymbol(RHR);
    translator.emit(Taco(OP_BIT_NOT,retSym.id,CRHS.id));// ret = ~rhs
    retSym.isInitialized = CRHS.isInitialized;
    retSym.isConstant    = CRHS.isConstant   ;
    if( retSym.isInitialized ) {
      if( rType == MM_CHAR_TYPE ) {
	retSym.value.charVal = ~CRHS.value.charVal;
      } else if( rType == MM_INT_TYPE ) {
	retSym.value.intVal  = ~CRHS.value.intVal ;
      }
    }
    $$.symbol = retRef;
    $$.isReference = false;
  } break;

  case '!' : {
    if( !$$.isBoolean ) {
      throw syntax_error(@1,"Non boolean expression.");
    }
    std::swap($$.trueList,$$.falseList);
  } break;
    
  default: throw syntax_error(@$ , "Unknown unary operator.");
  }
} ;

%type <char> unary_operator;
unary_operator : "&" { $$ = '&'; } |"*" { $$ = '*'; } |"~" { $$='~';} |"+" { $$ = '+'; } |"-" { $$ = '-'; }|"!" { $$ = '!'; };

/// Type casting not supported yet...
%type <Expression> cast_expression;
cast_expression : unary_expression { std::swap($$,$1); }

%type <Expression> multiplicative_expression;
multiplicative_expression :
cast_expression {
  std::swap($$,$1);
} | multiplicative_expression mul_div_op cast_expression { // mul_div_op produces `*' or `/'
  // TODO : possible matrix/scalar , matrix/matrix multiplication.. and same for rhs
  // Dynoge
  emitScalarBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} | multiplicative_expression "%" cast_expression {
  emitIntegerBinaryOperation('%',translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> mul_div_op;
mul_div_op : "*" { $$ = '*'; } | "/" { $$ = '/'; }

%type <Expression> additive_expression;
additive_expression :
multiplicative_expression {
  std::swap($$,$1);
} | additive_expression add_sub_op multiplicative_expression { // add_sub op produces `+' or `-'
  // TODO : possible matrix addition / subtraction
  // Dynoge
  emitScalarBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);
} ;

%type <char> add_sub_op;
add_sub_op : "+" { $$ = '+'; } | "-" { $$ = '-'; } ;

%type <Expression> shift_expression;
shift_expression : additive_expression { std::swap($$,$1); }
| shift_expression bit_shift_op additive_expression {emitIntegerBinaryOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <char> bit_shift_op;
bit_shift_op : "<<" { $$ = '<'; } | ">>" { $$ = '>'; } ;

%type <Expression> relational_expression equality_expression;
relational_expression : shift_expression { std::swap($$,$1); }
| relational_expression rel_op shift_expression {emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;
equality_expression : relational_expression { std::swap($$,$1); }
| equality_expression eq_op relational_expression {emitConditionOperation($2,translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <char> rel_op eq_op;
rel_op : "<" { $$ = '<'; } | ">" { $$ = '>'; } | "<=" { $$ ='('; } | ">=" { $$ = ')'; } ;
eq_op : "==" { $$ = '='; } | "!=" { $$ = '!'; } ;

%type <Expression> AND_expression XOR_expression OR_expression;
AND_expression : equality_expression { std::swap($$,$1); }
| AND_expression "&" equality_expression {emitIntegerBinaryOperation('&',translator,*this,$$,$1,$3,@$,@1,@3);} ;
XOR_expression : AND_expression { std::swap($$,$1); }
| XOR_expression "^" AND_expression {emitIntegerBinaryOperation('^',translator,*this,$$,$1,$3,@$,@1,@3);} ;
OR_expression : XOR_expression { std::swap($$,$1);}
| OR_expression "|" XOR_expression {emitIntegerBinaryOperation('|',translator,*this,$$,$1,$3,@$,@1,@3);} ;

%type <unsigned int> instruction_mark;
instruction_mark : %empty { $$ = translator.nextInstruction(); } ;

%type <Expression> logical_AND_expression;
logical_AND_expression :
OR_expression {
  std::swap($$,$1);
} | logical_AND_expression "&&" instruction_mark OR_expression {
  if( !$1.isBoolean ) throw syntax_error(@1,"Non boolean operand.");
  if( !$1.isBoolean ) throw syntax_error(@4,"Non boolean operand.");
  translator.patchBack($1.trueList,$3);
  std::swap($$.trueList,$4.trueList);// constant time
  $$.falseList.splice($$.falseList.end(),$1.falseList);
  $$.falseList.splice($$.falseList.end(),$4.falseList);
  $$.isBoolean = true;
} ;

%type <Expression> logical_OR_expression;
logical_OR_expression :
logical_AND_expression {
  std::swap($$,$1);
} | logical_OR_expression "||" instruction_mark logical_AND_expression {
  if( !$1.isBoolean ) throw syntax_error(@1,"Non boolean operand.");
  if( !$4.isBoolean ) throw syntax_error(@4,"Non boolean operand.");
  translator.patchBack($1.falseList,$3);
  std::swap($$.falseList,$4.falseList);// constant time
  $$.trueList.splice($$.trueList.end(),$1.trueList);
  $$.trueList.splice($$.trueList.end(),$4.trueList);
  $$.isBoolean = true;
} ;

%type <unsigned int> insert_jump;
insert_jump : %empty {
  translator.emit(Taco(OP_GOTO));
  $$ = translator.nextInstruction();
} ;

%type <Expression> conditional_expression;
conditional_expression :
logical_OR_expression {
  std::swap($$,$1);
} | logical_OR_expression instruction_mark "?" expression insert_jump ":" expression {
  if( !$1.isBoolean ) throw syntax_error(@1,"Non boolean question.");
  translator.patchBack($1.trueList,$2); // on the mark
  translator.patchBack($1.falseList,$5); // after the jump
  translator.patchBack($5-1,translator.nextInstruction());
  DataType retType = MM_VOID_TYPE;// generate void dummy to avoid misuse of this expression
  SymbolRef retRef = translator.genTemp(retType);
  $$.symbol = retRef;
} ;

%type <Expression> assignment_expression;
assignment_expression :
conditional_expression { std::swap($$,$1); } |
unary_expression "=" assignment_expression {
  std::swap($$,$1);
  if( $$.isReference ) {
    if( translator.isSimpleReference($$) ) {
      DataType lType = translator.getSymbol($$.symbol).type;
      if( lType.isMatrix() ) {// RHS must be matrix
	/* TODO : support matrix assignment */
	// Dynoge
	throw syntax_error(@1,"Matrix operations not supported yet.");
      } else if( lType == MM_CHAR_TYPE or lType == MM_INT_TYPE or lType == MM_DOUBLE_TYPE ) {
	SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
	Symbol & RHS = translator.getSymbol(RHR);
	if( RHS.type != lType ) { // convert
	  RHR = typeCheck(RHR,lType,true,translator,*this,@3);
	}
	Symbol & CRHS = translator.getSymbol(RHR);
	Symbol & CLHS = translator.getSymbol($$.symbol);
	translator.emit(Taco(OP_COPY,CLHS.id,CRHS.id));// LHS = RHS
	CLHS.isInitialized = CRHS.isInitialized;
	if( CLHS.isInitialized ){
	  if( lType == MM_CHAR_TYPE ) CLHS.value.charVal = CRHS.value.charVal;
	  else if( lType == MM_INT_TYPE ) CLHS.value.intVal = CRHS.value.intVal;
	  else if( lType == MM_DOUBLE_TYPE ) CLHS.value.doubleVal = CRHS.value.doubleVal;
	}
	CLHS.isConstant = CRHS.isConstant;
      } else if( lType.isPointer() ) {
	Symbol & RHS = translator.getSymbol($3.symbol);
	if( RHS.type == lType ) {
	  Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	  translator.emit(Taco(OP_COPY,auxSym.id,RHS.id));// LHS = RHS
	} else {
	  throw syntax_error(@$,"Operand type mismatch.");
	}
      } else {
	throw syntax_error(@1,"Invalid operand.");
      }
    } else if( translator.isMatrixReference($$) ) {
      SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
      Symbol & RHS = translator.getSymbol(RHR);
      if( RHS.type != MM_DOUBLE_TYPE ) {
	DataType doubleType = MM_DOUBLE_TYPE;
	RHR = typeCheck(RHR,doubleType,true,translator,*this,@3);
      }
      Symbol & CRHS = translator.getSymbol(RHR);
      Symbol & CLHS = translator.getSymbol($$.symbol);
      Symbol & auxSym = translator.getSymbol($$.auxSymbol);
      translator.emit(Taco(OP_LXC,CLHS.id,auxSym.id,CRHS.id));// m[off] = RHS
    } else if( translator.isPointerReference($$) ) {
      DataType lType = translator.getSymbol($$.symbol).type;
      if( lType.isPointer() ) {
	Symbol & RHS = translator.getSymbol($3.symbol);
	if( RHS.type == lType ) {
	  Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	  translator.emit(Taco(OP_L_DEREF,auxSym.id,RHS.id));
	} else {
	  throw syntax_error(@$,"Operand type mismatch.");
	}
      } else if( lType == MM_CHAR_TYPE or lType == MM_INT_TYPE or lType == MM_DOUBLE_TYPE ) {
	SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
	Symbol & RHS = translator.getSymbol(RHR);
	if( RHS.type != lType ) {// convert to lType
	  RHR = typeCheck(RHR,lType,true,translator,*this,@3);
	}
	Symbol & CRHS = translator.getSymbol(RHR);
	Symbol & auxSym = translator.getSymbol($$.auxSymbol);
	translator.emit(Taco(OP_L_DEREF,auxSym.id,CRHS.id));// *ptr = RHS
      } else {
	throw syntax_error(@1,"Invalid operand.");
      }
    }
  } else {
    throw syntax_error(@1,"Assignment to non-l-value.");
  }
  
} ;

%type <Expression> expression;
expression :
assignment_expression { std::swap($$,$1); } ;

/**********************************************************************/




/**********************************************************************/
/*********************DECLARATION NON-TERMINALS************************/
/**********************************************************************/

/* Empty declarator list not supported i.e : `int ;' is not syntactically correct */
/* Also since only one type specifier is supported , `declaration_specifiers' is omitted */
declaration : type_specifier initialized_declarator_list ";" {translator.typeContext.pop();} ;

%type <DataType> type_specifier;
type_specifier :
  "void" { translator.typeContext.push( MM_VOID_TYPE ); }
| "char" { translator.typeContext.push( MM_CHAR_TYPE ); }
|  "int" { translator.typeContext.push( MM_INT_TYPE );  }
|"double" {translator.typeContext.push( MM_DOUBLE_TYPE);}
|"Matrix" {translator.typeContext.push( MM_MATRIX_TYPE);} ;

initialized_declarator_list :
initialized_declarator | initialized_declarator_list "," initialized_declarator ;

initialized_declarator :
declarator { } |
declarator "=" expression {
  Symbol & defSym = translator.getSymbol($1);
  if( defSym.type.isMatrix() ) {
    throw syntax_error(@3,"Matrix operations not supported yet.");
    if( defSym.type.isStaticMatrix() ) {//
    } else {// Dynoge
    }
  } else if( defSym.type.isPointer() ) {
    Symbol & rSym = translator.getSymbol($3.symbol);
    if( rSym.type == defSym.type ) {
      translator.emit(Taco(OP_COPY,defSym.id,rSym.id));
    } else {
      throw syntax_error(@$,"Operand type mismatch.");
    }
  } else if( defSym.type == MM_CHAR_TYPE or defSym.type == MM_INT_TYPE or defSym.type == MM_DOUBLE_TYPE) {
    SymbolRef RHR = getScalarBinaryOperand(translator,*this,@3,$3);
    Symbol & RHS = translator.getSymbol(RHR);
    if( RHS.type != defSym.type ) { // convert
      RHR = typeCheck(RHR,defSym.type,true,translator,*this,@3);
    }
    Symbol & CRHS = translator.getSymbol(RHR);
    Symbol & LHS = translator.getSymbol($1);
    translator.emit(Taco(OP_COPY,LHS.id,CRHS.id));// LHS = CRHS
    LHS.isInitialized = CRHS.isConstant;
    if( LHS.isInitialized ){
      if( defSym.type == MM_CHAR_TYPE ) LHS.value.charVal = CRHS.value.charVal;
      else if( defSym.type == MM_INT_TYPE ) LHS.value.intVal = CRHS.value.intVal;
      else if( defSym.type == MM_DOUBLE_TYPE ) LHS.value.doubleVal = CRHS.value.doubleVal;
    }
  } else {
    throw syntax_error(@$,"Syntax error.");
  }
  
} |
declarator "=" "{" initializer_row_list "}" { // for static matrices
  Symbol & matSym = translator.getSymbol($1);
  if( matSym.type.isStaticMatrix() ) {
    //initializers are always non-empty ... so $4[0] will never throw runtime error
    if( matSym.type.rows != $4.size() or matSym.type.cols != $4[0].size() ) {
      throw syntax_error(@4,"Size mismatch. Matrix dimensions don't match initializer.");
    }
    int offset = 2 * SIZE_OF_INT; // initial offset
    for( int row = 0 ; row < matSym.type.rows ; row++ ) {
      for( int col = 0 ; col < matSym.type.cols ; col++ , offset += SIZE_OF_DOUBLE ) {
	Symbol & elemSym = translator.getSymbol($4[row][col]);
	translator.emit(Taco(OP_LXC,matSym.id,std::to_string(offset),elemSym.id));
      }
    }// copy all elements
  } else {
    throw syntax_error(@4,"Cannot statically initialize non-static matrices.");
  }
};

%type < SymbolRef > declarator;
declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  /* TODO : If it is a function declaration in a global scope let it pass. */
  if( translator.currentEnvironment() == 0 and symbol.type == MM_FUNC_TYPE ) {
    throw syntax_error( @$ , "Function declaration not supported yet." );
  } else if( symbol.type.isIllegalDecalaration() ) {
    throw syntax_error( @$ , "Invalid type for declaration." );
  }
  translator.updateSymbolTable($2.first);
  translator.typeContext.top().pointers -= $1;
} ;

%type <unsigned int> optional_pointer;
optional_pointer : %empty { $$ = 0; } |
optional_pointer "*" {
  if( translator.typeContext.top() == MM_MATRIX_TYPE ) {
    throw syntax_error(@$, "Matrices cannot have pointers.");
  }
  translator.typeContext.top().pointers++;
  $$ = $1 + 1;
} ;

%type < SymbolRef > direct_declarator;
direct_declarator :
/* Variable declaration */
IDENTIFIER {
  try {
    // create a new symbol in current scope
    DataType &  curType = translator.typeContext.top() ;
    SymbolTable & table = translator.currentTable();
    if(translator.parameterDeclaration) {
      $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::PARAM));
    } else if( curType == MM_MATRIX_TYPE ) {
      $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::LINK)); //create a dyanamic link
    } else {
      $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::LOCAL));
    }
  } catch ( ... ) {
    /* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
  
}
|
/* Function declaration */
IDENTIFIER "(" {
  /* Create a new environment (to store the parameters and return type) */
  if(translator.parameterDeclaration) {
    throw syntax_error( @$ , "Syntax error." ); 
  }
  translator.parameterDeclaration = true;
  
  unsigned int oldEnv = translator.currentEnvironment();
  unsigned int newEnv = translator.newEnvironment($1);
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
  DataType &  curType = translator.typeContext.top();
  try {
    currTable.lookup("ret#" , curType , SymbolType::RETVAL );// push return type
  } catch ( ... ) {
    throw syntax_error( @$ , "Unexpected error. Debug compiler." );
  }
} optional_parameter_list ")" {
  unsigned int currEnv = translator.currentEnvironment();
  SymbolTable & currTable = translator.currentTable();
  currTable.params = $4;
  
  translator.parameterDeclaration = false;
  translator.popEnvironment();
  try {
    SymbolTable & outerTable = translator.currentTable();
    DataType symbolType = MM_FUNC_TYPE ;
    $$ = std::make_pair(translator.currentEnvironment() ,outerTable.lookup($1,symbolType,SymbolType::LOCAL));
    Symbol & newSymbol = translator.getSymbol($$);
    newSymbol.child = currEnv;
  } catch ( ... ) {/* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }
  
}
|
/* Matrix declaration. Empty dimensions not allowed during declaration. Exactly two dimensions are needed. */
IDENTIFIER "[" expression "]" "[" expression "]" {  // only 2-dimensions to be supported
    
  DataType &  curType = translator.typeContext.top() ;
  if(curType != MM_MATRIX_TYPE) {
    throw syntax_error(@$,"Incompatible type for matrix declaration.");
  }
  
  if(translator.parameterDeclaration) {
    throw syntax_error(@$,"Dimensions cannot be specified while declaring parameters.");
  }
  
  try {
    // create a new symbol in current scope
    SymbolTable & table = translator.currentTable();
    $$ = std::make_pair(translator.currentEnvironment(),table.lookup($1,curType,SymbolType::LOCAL));
    
    SymbolRef rowRef = getIntegerBinaryOperand(translator,*this,@3,$3);
    SymbolRef colRef = getIntegerBinaryOperand(translator,*this,@6,$6);
    Symbol & curSymbol = translator.getSymbol($$);
    Symbol & rowSym = translator.getSymbol(rowRef);
    Symbol & colSym = translator.getSymbol(colRef);
    
    if( rowSym.isConstant and colSym.isConstant ) {
      if( rowSym.type == MM_CHAR_TYPE ) {
	if(rowSym.value.charVal<=0) throw syntax_error(@$,"Non-positive matrix dimension.");
	curSymbol.type.rows = rowSym.value.charVal;
      } else {
	if(rowSym.value.intVal<=0) throw syntax_error(@$,"Non-positive matrix dimension.");
	curSymbol.type.rows = rowSym.value.intVal;
      }
      if( colSym.type == MM_CHAR_TYPE ) {
	if(colSym.value.charVal<=0) throw syntax_error(@$,"Non-positive matrix dimension.");
	curSymbol.type.cols = colSym.value.charVal;
      } else {
	if(colSym.value.intVal<=0) throw syntax_error(@$,"Non-positive matrix dimension.");
	curSymbol.type.cols = colSym.value.intVal;
      }
    } else {
      // Check environment. Globally declared dynamic matrices should not be allowed.
      curSymbol.symType = SymbolType::LINK;
    }

    // TODO : write allocator opcodes around here.
    if(rowSym.type == MM_CHAR_TYPE) {
      DataType intType = MM_INT_TYPE;
      rowRef = typeCheck(rowRef,intType,true,translator,*this,@3);
      Symbol & rowInt = translator.getSymbol(rowRef);
      Symbol & matSymbol = translator.getSymbol($$);
      translator.emit(Taco(OP_LXC,matSymbol.id,"0",rowInt.id));// m[0] = # of rows
    } else {
      translator.emit(Taco(OP_LXC,curSymbol.id,"0",rowSym.id));
    }
    
    if(colSym.type == MM_CHAR_TYPE) {
      DataType intType = MM_INT_TYPE;
      colRef = typeCheck(colRef,intType,true,translator,*this,@6);
      Symbol & colInt = translator.getSymbol(colRef);
      Symbol & matSymbol = translator.getSymbol($$);
      translator.emit(Taco(OP_LXC,matSymbol.id,std::to_string(SIZE_OF_INT),colInt.id));//m[4] = # of cols
    } else {
      translator.emit(Taco(OP_LXC,curSymbol.id,std::to_string(SIZE_OF_INT),colSym.id));//m[4] = # of cols
    }
  } catch ( syntax_error se ) {
    throw se;
  } catch ( ... ) {/* Already declared in current scope */
    throw syntax_error( @$ , $1 + " has already been declared in this scope." );
  }

} ;

%type <unsigned int> optional_parameter_list;
optional_parameter_list :
%empty { $$ = 0; } | parameter_list { $$ = $1; } ;

%type <unsigned int> parameter_list;
parameter_list : parameter_declaration { $$ = 1; }
| parameter_list "," parameter_declaration { $$ = $1 + 1; } ;

parameter_declaration :
type_specifier declarator { translator.typeContext.pop(); } ;

%type <std::vector<std::vector<SymbolRef> > > initializer_row_list;
initializer_row_list :
initializer_row {
  $$.push_back($1);
} |
initializer_row_list ";" initializer_row {
  std::swap($$,$1);
  if($$[0].size() != $3.size()) {
    throw syntax_error(@$,"Size mismatch in initializer row.");
  }
  $$.push_back($3);
} ;

%type <std::vector<SymbolRef> > initializer_row;
initializer_row :
/* Nested brace initializers are not supported : { {2;3} ; 4 } 
   Hence the non-terminal initializer_row does not again produce initializer */
expression {
  DataType elemType = MM_DOUBLE_TYPE;
  SymbolRef E = typeCheck($1.symbol,elemType,true,translator,*this,@1);
  $$.push_back( E );
} |
initializer_row "," expression {
  std::swap($$,$1);
  DataType elemType = MM_DOUBLE_TYPE;
  SymbolRef E = typeCheck($3.symbol,elemType,true,translator,*this,@3);
  $$.push_back( E );
} ;

/* 
   Also, non-trivial designated initializers not supported.
   i.e int arr[10] = {0,[4]=2}; // ... not supported
   Hence all designator non-terminals are omitted.
*/

/**********************************************************************/




/**********************************************************************/
/***********************STATEMENT NON-TERMINALS************************/
/**********************************************************************/

%type <AddressList> statement;
statement :
  compound_statement { std::swap($$,$1); }
| selection_statement { std::swap($$,$1); }
| iteration_statement { std::swap($$,$1); }
| jump_statement      { std::swap($$,$1); }
| expression_statement { } ;

%type <AddressList> compound_statement;
compound_statement :
"{" {
  /* LBrace encountered : push a new symbol table and link it to its parent */
  unsigned int oldEnv = translator.currentEnvironment();
  DataType voidType = MM_VOID_TYPE; // 
  unsigned int newEnv = translator.newEnvironment("");
  SymbolRef ref = translator.genTemp( oldEnv, voidType );
  Symbol & temp = translator.getSymbol(ref);
  translator.currentTable().name = temp.id;
  temp.child = newEnv;
  SymbolTable & currTable = translator.currentTable();
  currTable.parent = oldEnv;
} optional_block_item_list "}" {
  // TODO : do scope post-processing
  std::swap($$,$3);
  translator.popEnvironment();
} ;

%type <AddressList> optional_block_item_list;
optional_block_item_list :
%empty { } |
block_item_list { std::swap($$,$1); } ;

%type <AddressList> block_item_list;
block_item_list : block_item {
  translator.patchBack($1,translator.nextInstruction());
} |
block_item_list instruction_mark block_item {
  translator.patchBack($1,$2);
  std::swap($$,$3);
}

%type <AddressList> block_item;
block_item : declaration { } | statement { std::swap($$,$1); } ;

expression_statement :
optional_expression ";" { // patch back all jumps to the next instruction
  translator.patchBack($1.trueList,translator.nextInstruction());
  translator.patchBack($1.falseList,translator.nextInstruction());
} ;

/* 1 shift-reduce conflict arising out of this rule. Only this one is to be expected. */
%type <AddressList> selection_statement;
selection_statement :
"if" "(" expression ")" instruction_mark statement {
  if( !$3.isBoolean ) {
    throw syntax_error(@3,"Not a boolean expression.");
  }
  translator.patchBack($3.trueList,$5);
  std::swap($$,$3.falseList);
  $$.splice($$.end(),$6);
}
|
"if" "(" expression ")" instruction_mark statement "else" insert_jump statement {
  if( !$3.isBoolean ) {
    throw syntax_error(@3,"Not a boolean expression.");
  }
  translator.patchBack($3.trueList,$5);
  translator.patchBack($3.falseList,$8);
  std::swap($$,$6);$$.push_back($8-1);
  $$.splice($$.end(),$9);
}
;

%type <AddressList> iteration_statement;
iteration_statement :
"while" "(" instruction_mark expression ")" instruction_mark statement {
  if( !$4.isBoolean ) {
    throw syntax_error(@4,"Not a boolean expression.");
  }
  unsigned int loopInstruction = translator.nextInstruction();
  translator.emit(Taco(OP_GOTO));
  translator.patchBack(loopInstruction,$3); // primary loop
  translator.patchBack($7,$3); // shortcut loop
  translator.patchBack($4.trueList,$6); // iterate
  std::swap($$,$4.falseList); // terminate
}
|
"do" instruction_mark statement "while" "(" instruction_mark expression ")" ";" {
  if( !$7.isBoolean ) {
    throw syntax_error(@7,"Not a boolean expression.");
  }
  translator.patchBack($7.trueList,$2); // primary loop
  translator.patchBack($3,$6);
  std::swap($$,$7.falseList); // terminate
}
|
"for" "("
optional_expression ";"              // initializer expression
instruction_mark expression ";"      // nonempty invariant expression
instruction_mark optional_expression // variant expression
")" instruction_mark statement {
  if( !$6.isBoolean ) {
    throw syntax_error(@6,"Not a boolean expression.");
  }
  unsigned int loopInstruction = translator.nextInstruction();
  translator.emit(Taco(OP_GOTO));
  
  translator.patchBack(loopInstruction,$5); // primary loop
  translator.patchBack($12,$5); // shortcut loop
  
  translator.patchBack($3.trueList,$5); //
  translator.patchBack($3.falseList,$5); // link totally
  
  translator.patchBack($6.trueList,$8); // iterate

  translator.patchBack($9.trueList,$11); //
  translator.patchBack($9.falseList,$11); // link totally
  
  std::swap($$,$6.falseList); // terminate
}
/* Declaration inside for is not supported */
;

%type <AddressList> jump_statement;
jump_statement :
"return" optional_expression ";" {
  
}
;

%type <Expression> optional_expression;
optional_expression : %empty { } | expression { std::swap($$,$1); } ;

/**********************************************************************/



/**********************************************************************/
/**********************DEFINITION NON-TERMINALS************************/
/**********************************************************************/

%start translation_unit;

translation_unit :
external_declarations "EOF" {
  // TODO : post-translation processing / optimizations
  // translation completed
  YYACCEPT;
}
;

external_declarations :
%empty | external_declarations external_declaration { };

external_declaration :
declaration { } | function_definition { } ;

function_definition :
type_specifier function_declarator "{" {
  // Push the same environment back onto the stack
  // to continue declaration within the same scope
  Symbol & symbol = translator.getSymbol($2);
  unsigned int functionScope = symbol.child;
  // $2->value = address of this function
  translator.environment.push(functionScope);
  translator.emit(Taco(OP_FUNC_START,translator.currentTable().name));
} optional_block_item_list "}" {
  translator.patchBack($5,translator.nextInstruction());
  translator.emit(Taco(OP_FUNC_END,translator.currentTable().name));
  // TODO : "sort out" the current environment for generation of stack frame
  translator.environment.pop();
  translator.typeContext.pop(); // corresponding to the type_specifier
} ;

%type < SymbolRef > function_declarator;
function_declarator :
optional_pointer direct_declarator {
  $$ = $2;
  Symbol & symbol = translator.getSymbol($$);
  if( symbol.type != MM_FUNC_TYPE ) {
    throw syntax_error( @$ , " Improper function definition : parameter list not found." );
  }
} ;

/**********************************************************************/

%%

/* Bison parser error . 
   Sends a message to the translator and aborts any further parsing. */
void yy::mm_parser::error (const location_type& loc,const std::string &msg) {
  translator.error(loc,msg);
  throw syntax_error(loc,msg);
}

SymbolRef getScalarBinaryOperand(mm_translator & translator,
				 yy::mm_parser& parser,
				 const yy::location& loc,
				 Expression & expr
				 ) {
  SymbolRef ret ;
  DataType rType = translator.getSymbol(expr.symbol).type;
  if( expr.isReference ) {
    if( translator.isSimpleReference(expr) ) {
      if( rType.isMatrix() ) {
	parser.error(loc, "Unknown error. Debug compiler.");
      }
      ret = expr.symbol;
    } else if( translator.isPointerReference(expr) ) {
      if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE or rType == MM_DOUBLE_TYPE ) {
	ret = expr.symbol;
      } else { // non scalar operand
        parser.error(loc , "Operand not allowed.");
      }
    } else if( translator.isMatrixReference(expr) ) { // matrix element
      DataType elementType = MM_DOUBLE_TYPE;
      ret = translator.genTemp(elementType);
      Symbol & retSymbol = translator.getSymbol(ret);
      Symbol & rhs = translator.getSymbol(expr.symbol);
      Symbol & auxSymbol = translator.getSymbol(expr.auxSymbol);
      translator.emit(Taco(OP_RXC,retSymbol.id,rhs.id,auxSymbol.id));// rhs = m[off]
    } else {
      parser.error(loc , "Invalid operand.");
    }
  } else if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE or rType == MM_DOUBLE_TYPE ) {
    ret = expr.symbol;
  } else { // non scalar operand
    parser.error(loc , "Invalid operand.");
  }
  return ret;
}

SymbolRef getIntegerBinaryOperand(mm_translator & translator,
				  yy::mm_parser& parser,
				  const yy::location& loc,
				  Expression & expr
				  ) {
  SymbolRef ret ;
  DataType rType = translator.getSymbol(expr.symbol).type;
  if( expr.isReference ) {
    if( translator.isSimpleReference(expr) ) {
      if( rType.isMatrix() or rType == MM_DOUBLE_TYPE ) {
        parser.error(loc, "Non integral operand not allowed.");
      }
      ret = expr.symbol;
    } else if( translator.isPointerReference(expr) ) {
      if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE ) {
	ret = expr.symbol;
      } else { // non scalar operand
        parser.error(loc , "Operand not allowed.");
      }
    } else if( translator.isMatrixReference(expr) ) { // matrix element
      parser.error(loc , "Non integral operand not allowed.");
    } else {
      parser.error(loc , "Invalid operand.");
    }
  } else if( rType == MM_CHAR_TYPE or rType == MM_INT_TYPE ) {
    ret = expr.symbol;
  } else { // non scalar operand
    parser.error(loc , "Invalid operand.");
  }
  return ret;
}

SymbolRef typeCheck(SymbolRef ref,
		    DataType & type,
		    bool convert,
		    mm_translator & translator,
		    yy::mm_parser & parser,
		    const yy::location & loc
		    ) {
  DataType baseType = translator.getSymbol( ref ).type;
  if( baseType != type ) {
    if( convert ) {
      SymbolRef ret = translator.genTemp(type);
      Symbol & retSymbol = translator.getSymbol(ret);
      Symbol & rhs = translator.getSymbol( ref );
      retSymbol.isInitialized = rhs.isInitialized;
      retSymbol.isConstant    = rhs.isConstant   ;
      if( type == MM_CHAR_TYPE ) {
	translator.emit(Taco(OP_CONV_TO_CHAR,retSymbol.id,rhs.id));
	if( rhs.type == MM_CHAR_TYPE ) {
	  retSymbol.value.charVal = rhs.value.charVal;
	} else if( rhs.type == MM_INT_TYPE ) {
	  retSymbol.value.charVal = (char)rhs.value.intVal;
	} else if( rhs.type == MM_DOUBLE_TYPE ) {
	  retSymbol.value.charVal = (char)rhs.value.doubleVal;
	}
      } else if( type == MM_INT_TYPE ) {
	translator.emit(Taco(OP_CONV_TO_INT,retSymbol.id,rhs.id));
	if( rhs.type == MM_CHAR_TYPE ) {
	  retSymbol.value.intVal = (int)rhs.value.charVal;
	} else if( rhs.type == MM_INT_TYPE ) {
	  retSymbol.value.intVal = rhs.value.intVal;
	} else if( rhs.type == MM_DOUBLE_TYPE ) {
	  retSymbol.value.intVal = (int)rhs.value.doubleVal;
	}
      } else if( type == MM_DOUBLE_TYPE ) {
	translator.emit(Taco(OP_CONV_TO_DOUBLE,retSymbol.id,rhs.id));
	if( rhs.type == MM_CHAR_TYPE ) {
	  retSymbol.value.doubleVal = (double)rhs.value.charVal;
	} else if( rhs.type == MM_INT_TYPE ) {
	  retSymbol.value.doubleVal = (double)rhs.value.intVal;
	} else if( rhs.type == MM_DOUBLE_TYPE ) {
	  retSymbol.value.doubleVal = rhs.value.doubleVal;
	}
      }
      return ret;
    } else {
      parser.error(loc , "Cannot convert into requested type.");
    }
  }
  return ref;
}

void emitScalarBinaryOperation(char opChar ,
			       mm_translator &translator,
			       yy::mm_parser &parser,
			       Expression & retExp,
			       Expression & lExp,
			       Expression & rExp,
			       const yy::location &loc,
			       const yy::location &lLoc,
			       const yy::location &rLoc
			       ) {
  SymbolRef LHR , RHR;
  LHR = getScalarBinaryOperand(translator,parser,lLoc,lExp); // get lhs
  RHR = getScalarBinaryOperand(translator,parser,rLoc,rExp); // get rhs
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType == MM_VOID_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  
  LHR = typeCheck(LHR,retType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,retType,true,translator,parser,rLoc);
  
  SymbolRef retRef;
  bool lTemp = translator.isTemporary(LHR) , rTemp = translator.isTemporary(RHR);
  if( !lTemp and !rTemp ) { retRef = translator.genTemp(retType); }//generate new
  else { if( lTemp ) retRef = LHR;else retRef = RHR; }
  
  Symbol & retSymbol = translator.getSymbol(retRef);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);

  retSymbol.isInitialized = CLHS.isInitialized and CRHS.isInitialized;
  retSymbol.isConstant    = CLHS.isConstant    and CRHS.isConstant   ;
  
  if( opChar == '*' ) translator.emit(Taco(OP_MULT,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '/' ) translator.emit(Taco(OP_DIV,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '+' ) translator.emit(Taco(OP_PLUS,retSymbol.id,CLHS.id,CRHS.id));
  else if( opChar == '-' ) translator.emit(Taco(OP_MINUS,retSymbol.id,CLHS.id,CRHS.id));

  if(retSymbol.isInitialized){// propagate initial value
    if(retType == MM_CHAR_TYPE) {
      switch(opChar){
      case '*' : retSymbol.value.charVal = CLHS.value.charVal*CRHS.value.charVal; break;
      case '/' : {
	if( CRHS.value.charVal == 0 ) {
	  parser.error(rLoc,"Division by zero.");
	}
	retSymbol.value.charVal = CLHS.value.charVal/CRHS.value.charVal;
      }break;
      case '+' : retSymbol.value.charVal = CLHS.value.charVal+CRHS.value.charVal; break;
      case '-' : retSymbol.value.charVal = CLHS.value.charVal-CRHS.value.charVal; break;
      default:break;
      };
    } else if(retType == MM_INT_TYPE) {
      switch(opChar){
      case '*' : retSymbol.value.intVal = CLHS.value.intVal*CRHS.value.intVal; break;
      case '/' : {
	if( CRHS.value.charVal == 0 ) {
	  parser.error(rLoc,"Division by zero.");
	}
        retSymbol.value.intVal = CLHS.value.intVal / CRHS.value.intVal;
      }break;
      case '+' : retSymbol.value.intVal = CLHS.value.intVal + CRHS.value.intVal; break;
      case '-' : retSymbol.value.intVal = CLHS.value.intVal - CRHS.value.intVal; break;
      default:break;
      };
    } else if(retType == MM_DOUBLE_TYPE) {
      switch(opChar){
      case '*' : retSymbol.value.doubleVal = CLHS.value.doubleVal * CRHS.value.doubleVal; break;
      case '/' : retSymbol.value.doubleVal = CLHS.value.doubleVal / CRHS.value.doubleVal; break;
      case '+' : retSymbol.value.doubleVal = CLHS.value.doubleVal + CRHS.value.doubleVal; break;
      case '-' : retSymbol.value.doubleVal = CLHS.value.doubleVal - CRHS.value.doubleVal; break;
      default:break;
      };
    }
  }
  retExp.symbol = retRef;
}

void emitIntegerBinaryOperation(char opChar,
				mm_translator &translator,
				yy::mm_parser &parser,
				Expression &retExp,
				Expression &lExp,
				Expression &rExp,
				const yy::location &loc,
				const yy::location &lLoc,
				const yy::location &rLoc
				) {
  SymbolRef LHR , RHR;
  LHR = getIntegerBinaryOperand(translator,parser,lLoc,lExp);
  RHR = getIntegerBinaryOperand(translator,parser,rLoc,rExp);
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType retType = mm_translator::maxType(LHS.type,RHS.type);
  if( retType != MM_CHAR_TYPE and retType != MM_INT_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  LHR = typeCheck(LHR,retType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,retType,true,translator,parser,rLoc);

  SymbolRef retRef;
  bool lTemp = translator.isTemporary(LHR) , rTemp = translator.isTemporary(RHR);
  if( !lTemp and !rTemp ) { retRef = translator.genTemp(retType); }//generate new
  else { if( lTemp ) retRef = LHR;else retRef = RHR; }
  
  Symbol & retSymbol = translator.getSymbol(retRef);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);

  retSymbol.isInitialized = CLHS.isInitialized and CRHS.isInitialized;
  retSymbol.isConstant    = CLHS.isConstant    and CRHS.isConstant   ;
  
  if( opChar == '%' ) translator.emit(Taco(OP_MOD,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '<' ) translator.emit(Taco(OP_SHL,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '>' ) translator.emit(Taco(OP_SHR,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '&' ) translator.emit(Taco(OP_BIT_AND,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '^' ) translator.emit(Taco(OP_BIT_XOR,retSymbol.id,CLHS.id,CRHS.id));
  if( opChar == '|' ) translator.emit(Taco(OP_BIT_OR,retSymbol.id,CLHS.id,CRHS.id));
  
  if(retSymbol.isInitialized){// propagate initial value
    if(retType == MM_CHAR_TYPE) {
      switch(opChar){
      case '%' : {
	if( CRHS.value.charVal == 0 ) {
	  parser.error(rLoc,"Division by zero.");
	}
	retSymbol.value.charVal = CLHS.value.charVal % CRHS.value.charVal;
      }break;
      case '<' : retSymbol.value.charVal = CLHS.value.charVal << CRHS.value.charVal; break;
      case '>' : retSymbol.value.charVal = CLHS.value.charVal >> CRHS.value.charVal; break;
      case '&' : retSymbol.value.charVal = CLHS.value.charVal & CRHS.value.charVal; break;
      case '^' : retSymbol.value.charVal = CLHS.value.charVal ^ CRHS.value.charVal; break;
      case '|' : retSymbol.value.charVal = CLHS.value.charVal | CRHS.value.charVal; break;
      default:break;
      };
    } else if(retType == MM_INT_TYPE) {
      switch(opChar){
      case '%' : {
	if( CRHS.value.charVal == 0 ) {
	  parser.error(rLoc,"Division by zero.");
	}
        retSymbol.value.intVal = CLHS.value.intVal % CRHS.value.intVal;
      }break;
      case '<' : retSymbol.value.intVal = CLHS.value.intVal << CRHS.value.intVal; break;
      case '>' : retSymbol.value.intVal = CLHS.value.intVal >> CRHS.value.intVal; break;
      case '&' : retSymbol.value.intVal = CLHS.value.intVal & CRHS.value.intVal; break;
      case '^' : retSymbol.value.intVal = CLHS.value.intVal ^ CRHS.value.intVal; break;
      case '|' : retSymbol.value.intVal = CLHS.value.intVal | CRHS.value.intVal; break;
      default:break;
      };
    }
  }
  
  retExp.symbol = retRef;
}

void emitConditionOperation(char opChar,
			    mm_translator &translator,
			    yy::mm_parser &parser,
			    Expression &retExp,
			    Expression &lExp,
			    Expression &rExp,
			    const yy::location &loc,
			    const yy::location &lLoc,
			    const yy::location &rLoc
			    ) {
  SymbolRef LHR , RHR;
  LHR = getScalarBinaryOperand(translator,parser,lLoc,lExp); // get lhs
  RHR = getScalarBinaryOperand(translator,parser,rLoc,rExp); // get rhs
  Symbol & LHS = translator.getSymbol(LHR);
  Symbol & RHS = translator.getSymbol(RHR);
  DataType commonType = mm_translator::maxType(LHS.type,RHS.type);
  if( commonType != MM_CHAR_TYPE and commonType != MM_INT_TYPE and commonType != MM_DOUBLE_TYPE ) {
    parser.error(loc , "Invalid operands." );
  }
  LHR = typeCheck(LHR,commonType,true,translator,parser,lLoc);
  RHR = typeCheck(RHR,commonType,true,translator,parser,rLoc);
  Symbol & CLHS = translator.getSymbol(LHR);
  Symbol & CRHS = translator.getSymbol(RHR);
  retExp.isBoolean = true;
  retExp.trueList.push_back(translator.nextInstruction());
  switch( opChar ){
  case '<': translator.emit(Taco(OP_LT,"",CLHS.id,CRHS.id)); break;
  case '>': translator.emit(Taco(OP_GT,"",CLHS.id,CRHS.id)); break;
  case '(': translator.emit(Taco(OP_LTE,"",CLHS.id,CRHS.id)); break;
  case ')': translator.emit(Taco(OP_GTE,"",CLHS.id,CRHS.id)); break;
  case '=': translator.emit(Taco(OP_EQ,"",CLHS.id,CRHS.id)); break;
  case '!': translator.emit(Taco(OP_NEQ,"",CLHS.id,CRHS.id)); break;
  default : parser.error(loc,"Unknown relational operator.");
  }
  retExp.falseList.push_back(translator.nextInstruction());
  translator.emit(Taco(OP_GOTO,""));
}

/****************************************************************************************************/
