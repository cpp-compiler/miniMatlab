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

%code requires {
#include <string>
  class mm_translator;
 }

/* A translator object is used to construct its parser. */
%param {mm_translator &translator};

%code {
  /* Include translator definitions completely */
#include "ass4_15CS30035_translator.h"
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

%token <std::string> IDENTIFIER STRING_LITERAL CHARACTER_CONSTANT ;

/* Only 32-bit signed integer is supported for now */
%token <int> INTEGER_CONSTANT ;

/* All float-point arithmetic is in double precision only */
%token <double> FLOATING_CONSTANT ;

/************End token definitions*****************/
/**************************************************/


/**************************************************/
/**********Begin non-terminal definitions**********/

%type <int>
translation_unit
;

/************End non-terminal definitions**********/
/**************************************************/

/* Parse debugger */
%printer { yyoutput << $$ ; } <int> ;
%printer { yyoutput << $$ ; } <double> ;
%printer { yyoutput << $$ ; } <std::string> ;

%%

/**********************************************************************/
/*********************EXPRESSION NON-TERMINALS*************************/
/**********************************************************************/

primary_expression :
IDENTIFIER {
  
}
|
INTEGER_CONSTANT {
  
}
|
FLOATING_CONSTANT {
  
}
|
STRING_LITERAL {
  
}
|
"(" expression ")" {

}
;

postfix_expression:
primary_expression {
  
}
|
/* Dereference matrix element. Empty expression not allowed. */
postfix_expression "[" expression "]" {
  
}
|
/* Function call */
postfix_expression "(" optional_argument_list ")" {

}
|
postfix_expression "++" {

}
|
postfix_expression "--" {

}
|
postfix_expression ".'" {

}
;

optional_argument_list : %empty
| argument_list {
  
}
;

argument_list :
assignment_expression {
  
}
|
argument_list "," assignment_expression {

}
;

unary_expression :
postfix_expression {

}
|
"++" unary_expression {

}
|
"--" unary_expression {

}
|
unary_operator postfix_expression {

}
;

unary_operator :
"&" { /* get reference */ }
|"*" { /* dereference */ }
|"+" { /* unary plus */ }
|"-" { /* unary minus */  }

cast_expression : unary_expression { }

multiplicative_expression :
cast_expression {

}
|
multiplicative_expression "*" cast_expression {

}
|
multiplicative_expression "/" cast_expression {

}
|
multiplicative_expression "%" cast_expression {

}
;

additive_expression :
multiplicative_expression {

}
|
additive_expression "+" multiplicative_expression {

}
|
additive_expression "-" multiplicative_expression {

}
;

shift_expression :
multiplicative_expression {

}
|
shift_expression "<<" additive_expression {

}
|
shift_expression ">>" additive_expression {

}
;

relational_expression :
shift_expression {

}
|
relational_expression "<" shift_expression {
  
}
|
relational_expression ">" shift_expression {
  
}
|
relational_expression "<=" shift_expression {
  
}
|
relational_expression ">=" shift_expression {
  
}
;

equality_expression :
relational_expression {

}
|
equality_expression "==" relational_expression {

}
|
equality_expression "!=" relational_expression {

}
;

AND_expression :
equality_expression {

}
|
AND_expression "&" equality_expression {

}
;

XOR_expression :
AND_expression {

}
|
XOR_expression "^" AND_expression {

}
;

OR_expression :
XOR_expression {

}
|
OR_expression "|" XOR_expression {

}
;

logical_AND_expression :
OR_expression {

}
|
logical_AND_expression "&&" OR_expression {

}
;

logical_OR_expression :
logical_AND_expression {

}
|
logical_OR_expression "||" logical_AND_expression {

}
;

conditional_expression :
logical_OR_expression {

}
|
logical_OR_expression "?" expression ":" conditional_expression {
  
}
;

assignment_expression :
conditional_expression {

}
|
unary_expression "=" assignment_expression {

}
;

expression :
assignment_expression {

}
;

/**********************************************************************/




/**********************************************************************/
/*********************DECLARATION NON-TERMINALS************************/
/**********************************************************************/

/* Empty declarator list not supported */
/* i.e : `int ;' is not syntactically correct */
/* Also since only one type specifier is supported , `declaration_specifiers' is omitted */
declaration :
type_specifier initialized_declarator_list ";" {

}
;

type_specifier :
"void" {
  
}
|
"char" {
  
}
|
"int" {
  
}
|
"double" {
  
}
|
"Matrix" {
  
}
;

initialized_declarator_list :
initialized_declarator {

}
|
initialized_declarator_list "," initialized_declarator {

}
;

initialized_declarator :
declarator {
  /* TODO : Reminder for future self :
     Take care of errors like : void foo(int a = 2, int b);
  */
}
|
declarator "=" initializer {

}
;

declarator :
optional_pointer direct_declarator {

}
;

optional_pointer :
%empty
|
optional_pointer "*" {
  
}
;

direct_declarator :
/* Variable declaration */
IDENTIFIER {
  
}
|
/* Matrix declaration. Empty dimensions not allowed during declaration. */
direct_declarator "[" expression "]" {
  // only 2-dimensions to be supported
}
|
/* Function declaration */
IDENTIFIER "(" optional_parameter_list ")" {

}
;

optional_parameter_list : %empty
| parameter_list {
  
}
;

parameter_list :
parameter_declaration {

}
|
parameter_list "," parameter_declaration {

}
;

parameter_declaration :
type_specifier declarator {

}
;

initializer :
assignment_expression {
  
}
|
"{" initializer_row_list "}" {

}
;

initializer_row_list :
initializer_row {

}
|
initializer_row_list ";" initializer_row {

}
;

initializer_row :
/* Nested brace initializers are not supported : { {2;3} ; 4 } 
   Hence the non-terminal initializer_row does not again produce initializer */
expression {

}
|
initializer_row "," expression {

}
;

/* 
   Also, non-trivial designated initializers not supported.
   i.e int arr[10] = {0,[4]=2}; // ... not supported
   Hence all designator non-terminals are omitted.
*/

/**********************************************************************/




/**********************************************************************/
/***********************STATEMENT NON-TERMINALS************************/
/**********************************************************************/

statement :
compound_statement {

}
|
expression_statement {

}
|
selection_statement {

}
|
iteration_statement {

}
|
jump_statement {

}
;

compound_statement :
"{" optional_block_item_list "}" {

}
;

optional_block_item_list :
%empty
|
optional_block_item_list block_item {

}
;

block_item :
declaration {

}
|
statement {

}
;

expression_statement :
optional_expression ";" {
  
}
;

/* 1 shift-reduce conflict arising out of this rule. Only this one is to be expected. */
selection_statement :
"if" "(" expression ")" statement {

}
|
"if" "(" expression ")" statement "else" statement {

}
;

iteration_statement :
"while" "(" expression ")" statement {

}
|
"do" statement "while" "(" expression ")" ";" {

}
|
"for""("optional_expression";"optional_expression";"optional_expression")"statement {

}
/* Declaration inside for is not supported */
;

jump_statement :
"return" optional_expression ";" {

}
;

optional_expression :
%empty
|
expression {

}
;
/**********************************************************************/



/**********************************************************************/
/**********************DEFINITION NON-TERMINALS************************/
/**********************************************************************/

%start translation_unit;

translation_unit :
external_declarations "EOF" {
  // translation completed
  YYACCEPT;
}
;

external_declarations :
%empty
|
external_declarations external_declaration{
  
};

external_declaration :
declaration {

}
|
function_definition {
  
}
;

function_definition :
type_specifier declarator compound_statement {
  /* Check if declarator has a function definition inside or not */
}
;

%%

/* Bison parser error . Sends a message to the translator. Aborts any further parsing. */
void yy::mm_parser::error (const location_type& loc,const std::string &msg) {
  translator.error(loc,msg);
  throw syntax_error(loc,msg);
}
