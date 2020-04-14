%{
/* Global variable and Declaration */
#include "header.h"
#include "tok.h"
int yyerror(char *s);
int yyerror();
%}

/* For Definition */
DIGIT [1-9]*[0-9]+
identifier [i][d][A-Z][a-z]*
%%

[ ]*int[ ]+ { return INT; }
[ ]*char[ ]+ { return CHAR;}

[/][/].*
[\n] { yylineno++;}

{DIGIT}  { yylval.int_val = atoi(yytext); return NUM;} //positive
[ ]*[-]{DIGIT} { yylval.int_val = atoi(yytext); return NUM;} //negative
{identifier}+ { yylval.str = new std::string(yytext); return ID;}
["][a-zA-z]["] {yylval.int_val = (int)(yytext[1]); return NUM; 	} //ASCII

"(" { yylval.str = new std::string(yytext); return LEFT_PARENTHESE;}
")" { yylval.str = new std::string(yytext); return RIGHT_PARENTHESE;}
";" { yylval.str = new std::string(yytext); return SEMICOLON;}
"," { yylval.str = new std::string(yytext); return DOT;}
"{" { yylval.str = new std::string(yytext); return LEFT_BRACE;}
"}" { yylval.str = new std::string(yytext); return RIGHT_BRACE;}
"[" { yylval.str = new std::string(yytext); return LEFT_BUCKET;}
"]" { yylval.str = new std::string(yytext); return RIGHT_BUCKET;}

[ ]*[+][ ]* { return B_PLUS; }
[ ]*[-][ ]* { return B_MINUS;}
[ ]*[*][ ]* { return B_MULT;}
[ ]*[/][ ]* { return B_DIVIDE;}
[ ]*[=][=][ ]* { return B_EQUAL;}
[ ]*[=][ ]* { return B_ASSIGN;}
[ ]*[!] { return U_NOT;}
[ ]*[!][=][ ]* { return B_NOT_EQUAL;}
[ ]*[&][&][ ]* { return B_AND;}
[ ]*[|][|][ ]* { return B_OR;}
[ ]*[>][ ]* { return B_LARGER;}
[ ]*[<][ ]* { return B_SMALLER;}
[ ]*[>][=][ ]* { return B_NLESS_THAN;}
[ ]*[<][=][ ]* { return B_NLARGER_THAN;}

[ ]*while[ ]* { return WHILE;}
[ ]*break[ ]* { return BREAK;}
[ ]*else[ ]* { return ELSE;}
[ ]*if[ ]* { return IF;}
[ ]*return[ ]* { return RETURN;}
[ ]*print[ ]* { return PRINT;}
[ ]*read[ ]* { return READ;}

[ \t\0]* {};

. { printf("Error: undefined input\n");}

%%
