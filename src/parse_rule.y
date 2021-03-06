%{
/* Header file */
#include "header.h"
#include <string.h>
#include <stdlib.h>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <vector>
#include <algorithm>
/* function define */
int yyerror(char *s) ;
int yylex(void);
int push_stack(int type , string ID , int size , int ID_type); //push variable and array in stack if does not exist
int search_duplicate(string ID);                               //check an ID has been in stack or not
// Judge the input Op1 and Op2 , which one has more power (Priority)
int judgeOp(string OP1 , string OP2);
// Dealing the expression with the priority case (the expr "()" in expr , which need to do first)
string dealWithPriority(vector<string> List);
int whereVariable(string ID); //return variable location
// Dealing with the 2 Stack : Op stack and Data stack , to reach the expr
void dealing_Expr();
// Translate the result of expr to MIPS
void trans_code2MIPS(string OP,string Data1,string Data2,string current_register);
// Passing one variable into temp register in MIPS
void trans_var2MIPS(string data , string current_register);
// Do the If - else expr's translation
void if_else_toMIPS(size_t if_stmt_loc , size_t else_stmt_loc , int if_stmt_size , int else_stmt_size ,string if_expr);
// Do the while expr's translation
void while_toMIPS(size_t while_stmt_loc , int while_stmt_size , string while_expr);
// Doing the if's expr , and return the MIPS code in string , which the caller has this usage to concate in the final output
string make_if_expr(string OP , string data1, string data2 , int data_type);
// Doing the while's expr , and return the MIPS code in string , which the caller has this usage to concate in the final output
string make_while_expr(string OP , string data1, string data2 , int data_type);
string int2str(int &i);
int judge_category(string ID); // Return val : 0 -> pure number , 1 -> op , 2 -> var , 3 -> array , 4 -> function , -1 : not found
// print out the vector's content for debugging
void debugVector(vector<string> stack);
/* Output file */
ofstream assemFile;
ostringstream ss;
string _data = "";
string _text = "";
string _temp = "";
string _temp_expr = "";
string _temp_conidtion = "";
string *Variable_List = new string[100]; // Record the ID and it's stack location
string *Variable_List_type = new string[100]; // Record the ID's type
vector<string> function_list;// Record the function name we defined
vector<string> array_list;
vector<string> Lvalue_list;
vector<string> Rvalue_list;
string *a_reg = new string[4]; // Record the argument register
string *t_reg = new string[10]; // Only for Calculation
int a_reg_index = 0;
int t_reg_index = 0;
int stack_header = 1; // Record the current usage location
int stack_tailer = 1; // Record the current started location
int stack_global = 1;
int while_tag = 0;
int if_tag = 0;
int un_tag = 0;
int print_tag = 0;
int read_tag = 0;
%}

%code requires {
    typedef struct decl_type{
		int type;
		int size;
	}decl;
	typedef struct param_type{
		int type;
	}pm;
}

%union{
	int int_val;
	string* str;
	decl decl_T;
	pm param;
}

%start Program

/* Define  non-terminal*/
%type <str> declList
%type <str> declList_D
%type <decl_T> decl
%type <decl_T> varDecl_D
%type <decl_T> funDecl
%type <str> paramDeclList
%type <str> paramDeclListTail
%type <str> paramDeclListTail_D
%type <param> paramDecl
%type <param> paramDecl_D
%type <str> block
%type <str> varDeclList
%type <str> varDecl
%type <str> stmtList
%type <str> stmt
%type <str> stmtList_D
%type <str> expr
%type <str> expr_D
%type <str> unaryOp
%type <str> binOp
%type <str> exprIdTail
%type <str> exprList
%type <str> exprListTail
%type <str> exprListTail_D
%type <str> exprArrayTail

/* Define terminal */
%token <str> RIGHT_PARENTHESE
%token <str> LEFT_PARENTHESE
%token <str> RIGHT_BRACE
%token <str> LEFT_BRACE
%token <str> RIGHT_BUCKET
%token <str> LEFT_BUCKET
%token <str> SEMICOLON
%token <str> DOT
%token <int_val> NUM
%token <str> ID
%token <str> ID_CHAR
/* Define for type (non-terminal/terminal) */
%type <int_val> type
%token <str> INT
%token <str> CHAR

/* Define for operators (terminal) */
%token <int_val> U_NOT
%token <str> B_ASSIGN
%token <str> B_OR
%token <str> B_AND
%token <str> B_NOT_EQUAL
%token <str> B_EQUAL
%token <str> B_NLARGER_THAN
%token <str> B_NLESS_THAN
%token <str> B_SMALLER
%token <str> B_LARGER
%token <str> B_PLUS
%token <str> B_MINUS
%token <str> B_DIVIDE
%token <str> B_MULT
%token <str> WHILE
%token <str> BREAK
%token <str> ELSE
%token <str> IF
%token <str> RETURN
%token <str> PRINT
%token <str> READ

%%
Program: declList {
		cout << "Parse Successful!!" << endl;
		assemFile.open("run_compile.s");
		assemFile << "\t.data\n" << _data << "\t.text\n\t.globl main\n" << _text << "\n\tli	$v0 , 10\n\tsyscall\n";
	};

declList: /*empty*/ {}
	| declList_D declList {};

declList_D: type ID decl {

  	if($3.type==0){ //variable
			if($1==1){ //int
				push_stack(0,*$2,1,0);
				stack_global++;
			}
			else{ //char
				push_stack(0,*$2,1,1);
				stack_global++;
			}
		}

  	else if($3.type==1){ //array
			if($1==1){ //int
				push_stack(1,*$2,$3.size,0);
				stack_global += $3.size;
			}
			else{ //char
				push_stack(1,*$2,$3.size,1);
				stack_global += $3.size;
			}
		}

		else{ //function
			if($1==1){ //int
				if(*$2 == "idMain"){ //main function
					ss << "main:\n";
					_text = _text + ss.str() + _temp;
					ss.str("");
					_temp = "";
				}
				else{ //other function
					ss << *$2 <<":\n";
					function_list.push_back(*$2);
					_text += ss.str() + _temp+ "\tjr $ra\n";// return address
					ss.str("");
					_temp = "";
				   }
        }
			else{ // Char
				if(*$2 == "idMain"){
					ss << "main:\n";
					_text = _text+ss.str()+_temp;
					ss.str("");
				}
				else{ //other function
					ss << *$2 <<":\n";
					_text += ss.str() + _temp + "\tjr $ra\n"; // return address
					function_list.push_back(*$2);
					_temp = "";
					ss.str("");
				}
      }
			stack_tailer = stack_header; //current usage = current start
		}
	};

decl: varDecl_D { $$ = $1; }
	| funDecl { $$.type = 2; };

funDecl: LEFT_PARENTHESE paramDeclList RIGHT_PARENTHESE block{
		a_reg_index = 0;
};

paramDeclList: /* empty */ {}
	| paramDeclListTail {};

paramDeclListTail: paramDecl paramDeclListTail_D {};

paramDecl: type ID paramDecl_D {

  	if($3.type==0){ //variable
			if($1 == 1){ //int
				ss << "\t#" << "$a" << a_reg_index << " has be occupied with (INT) :" << *$2<<"\n" ;
				a_reg[a_reg_index] = *$2;
				_temp += ss.str();
				ss.str("");
				a_reg_index++;
			}
			else{//char
				ss << "\t#" << "$a" << a_reg_index << " has be occupied with (CHAR) :" << *$2<<"\n" ;
				a_reg[a_reg_index] = *$2;
				_temp += ss.str();
				ss.str("");
				a_reg_index++;
			}
		}

		else{//array
			if($1 == 1){ //int
				ss << "\t#" << "$a" << a_reg_index << " has be occupied with Array(Int) :" << *$2<<"\n" ;
				a_reg[a_reg_index] = *$2;
				_temp += ss.str();
				ss.str("");
				a_reg_index++;
			}
			else{//char
				ss << "\t#" << "$a" << a_reg_index << " has be occupied with Array(CHAR) :" << *$2<<"\n" ;
				a_reg[a_reg_index] = *$2;
				_temp += ss.str();
				ss.str("");
				a_reg_index++;
			}
		}
	};

paramDeclListTail_D: /* empty */{}
	| DOT paramDeclListTail {}
	;

paramDecl_D: { $$.type = 0;}//variable
	| LEFT_BUCKET RIGHT_BUCKET { $$.type = 1; }; //array

block: LEFT_BRACE varDeclList stmtList RIGHT_BRACE {
		*$$ = *$3;
	}
	;

varDeclList: /* empty */ {}
	| varDecl varDeclList {};

varDecl: type ID varDecl_D {
		if($3.type==0){ //variable
			if($1==1){//int
				push_stack(0,*$2,1,0);
			}
			else{//char
				push_stack(0,*$2,1,1);
			}
		}
		else if($3.type==1){//array
			if($1==1){//int
				push_stack(1,*$2,$3.size,0);
				array_list.push_back(*$2);
			}
			else{//char
				push_stack(1,*$2,$3.size,1);
				array_list.push_back(*$2);
			}
		}
	};

varDecl_D: SEMICOLON { //variable
		$$.type = 0;
		$$.size = 1;
	}
	| LEFT_BUCKET NUM RIGHT_BUCKET SEMICOLON {
	if($2 > 0)
	{
		//cout << "Get Array assignment which size is " << $2 << endl;
		$$.type = 1;
		$$.size = $2;
	}
	else{
		char s[32];
		strcpy(s,"Array Index can't be negative");
		yyerror(s);
	}
	};

stmtList: stmt stmtList_D {*$$ = *$1 + *$2;};

stmtList_D: /* empty */ { $$ = new string("");}
	| stmtList {*$$ = *$1;};

stmt: SEMICOLON {*$$ = "";}
	| expr SEMICOLON {
		// Record the arithmetic expr in $1
		//cout << "=====================List out expr:" << *$1 << endl;
		stringstream st(*$1);
		string token , open;
		while(getline(st, token , ',')){
			if(token != "="){
				//open = "Left value:";
				//cout << open << token << endl;
				Lvalue_list.push_back(token);
			}
			else{
				break;
			}
		}
		while(getline(st, token , ',')){
			open = "Right value:";
			//cout << open << token << endl;
			Rvalue_list.push_back(token);
		}
		// After that , we can dealing with Lvalue and Rvalue list
		//cout << "size of Lvalue: " << Lvalue_list.size() << endl;
		//cout << "size of Rvalue: " << Rvalue_list.size() << endl;
		// Dealing with assignment
		dealing_Expr();
		//
		*$$ = _temp_expr;
		_temp += _temp_expr;
		_temp_expr = "";
	}
	| RETURN expr SEMICOLON {
		/* Return expr */
		// If It is a variable or a pure number , translate to assembly directly.
		//cout << "Print Return : " << *$2 << endl;
		int judge = judge_category(*$2);
		if(judge == 2){// Variable
			int index=-1;
			for(int i = 0 ;i<stack_header ;i++){
				if(*$2 == Variable_List[i]){
					index = i;
					break;
				}
			}
			if(index != -1){
				// accquire temp register to load this memory's value and then
				string temp_r("$t");
				temp_r += int2str(t_reg_index);
				t_reg_index++;
				ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
				ss << "\tlw " << temp_r << ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << (index*4) << "\n";
				ss << "\taddi $v0 , $zero , 0\n"; // Clear the $v0
				ss << "\tadd $v0, $v0, " << temp_r<<"\n";
				_temp_expr += ss.str(); ss.str("");
			}
		}
		else if(judge == 0){
			// Pure number
			// accquire temp register to load this memory's value and then
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			ss << "\tlw " << temp_r << ", " << *$2 << "\n";
			ss << "\taddi $v0 , $zero , 0\n"; // Clear the $v0
			ss << "\tadd $v0, $v0, " << temp_r <<"\n";
			_temp_expr += ss.str(); ss.str("");
		}
		else if(judge == 3){
			// TODO array condition (return one variable in array or entire array)
		}
		else if(judge == 5){
			string a_temp("$a");
			for(int i = 0;i < a_reg_index ;i++){
				if(a_reg[i] == *$2){
					a_temp += int2str(i);
					break;
				}
			}
			ss << "\tadd $v0, $zero, " << a_temp <<"\n";
			_temp_expr += ss.str(); ss.str("");
		}
		else{
			// TODO Complex condition - like : return func(a,b) ...
		}
		*$$ = _temp_expr;
		_temp += _temp_expr;
		_temp_expr = "";
	}
	| BREAK SEMICOLON {
		/* Need to find out the scope , and then branch out of it */
		// Consider that the only 1 for-loop in this c-like language , so we only need to do "While"
		// Directly jump to EndWhile tag
		string str;
		str = "\tj EndWhile" + int2str(while_tag) + "\n";
		_temp += str;
		*$$ = str;
	}
	| IF LEFT_PARENTHESE expr RIGHT_PARENTHESE stmt ELSE stmt {
		/* Do if-else clause*/
		size_t if_stmt = _temp.find(*$5);
		size_t else_stmt = _temp.find(*$7);
		int if_stmt_sz = $5->size();
		int else_stmt_sz = $7->size();
		if_else_toMIPS(if_stmt,else_stmt,if_stmt_sz,else_stmt_sz,*$3);
		// Dealing with return string
		size_t if_stmt_after = _temp.find(_temp_conidtion);
		size_t end_stmt_after = _temp.find("Endif"+int2str(if_tag)+":\n");
		string if_sub_str = _temp.substr(if_stmt_after,end_stmt_after);
		if_tag++;
		*$$ = if_sub_str;
		_temp_conidtion = "";
	}
	| WHILE LEFT_PARENTHESE expr RIGHT_PARENTHESE stmt {
		/* Do while clause */
		size_t while_stmt = _temp.find(*$5);
		int while_stmt_sz = $5->size();
		while_toMIPS(while_stmt,while_stmt_sz,*$3);
		// Dealing with return string
		size_t while_start = _temp.find("WHILE"+int2str(while_tag)+":\n");
		size_t while_end = _temp.find("EndWhile"+int2str(while_tag)+":\n");
		string while_sub_str = _temp.substr(while_start,while_end);
		while_tag++;
		*$$ = while_sub_str;
	}
	| block {
		*$$ = *$1;
	}
	| PRINT ID {
		//cout << "Get print command , print : " << *$2 << endl;
		// add the print MIPS (Now support print int)
		string temp_r("$t");
		temp_r += int2str(t_reg_index);
		t_reg_index++;
		// Step 1 , find out where the ID
		int category = judge_category(*$2);
		if(category == 3){
			// array need to print out all the array
			// Step1 : Make the array[0]
			string array;
			int arr_index = 0;
			array = *$2 + "["+ int2str(arr_index) +"]";
			// Find it's size
			for(int i = 1; i < stack_header ; i++){
				if(array == Variable_List[i]){
					if(Variable_List_type[i] == "INT"){
						// Print it
						ss << "\t#For print_" << int2str(print_tag) << array << "\n";
						ss << "\taddi " << temp_r << ", $zero , 0\n";
						ss << "\taddi $sp , $sp , " << -(i*4) << "\n";
						ss << "\tlw " << temp_r << ", 0($sp)\n";
						ss << "\taddi $sp , $sp , " << (i*4) << "\n";
						ss << "\tli $v0 , 1\n";
						ss << "\tmove $a0, " << temp_r << "\n";
						ss << "\tsyscall\n";
						// And then change array's name
						arr_index++;
						array = *$2 + "[" + int2str(arr_index) + "]";
						print_tag++;
					}
					else if(Variable_List_type[i] == "CHAR"){
						// Print it
						ss << "\t#For print_"<< int2str(print_tag) << array << "\n";
						ss << "\taddi " << temp_r << ", $zero , 0\n";
						ss << "\taddi $sp , $sp , " << -(i*4) << "\n";
						ss << "\tlw " << temp_r << ", 0($sp)\n";
						ss << "\taddi $sp , $sp , " << (i*4) << "\n";
						ss << "\tli $v0 , 11\n";
						ss << "\tmove $a0, " << temp_r << "\n";
						ss << "\tsyscall\n";
						// And then change array's name
						arr_index++;
						array = *$2 + "[" + int2str(arr_index) + "]";
						print_tag++;
					}
				}
			}
		}
		else if(category == 2){
			// Variable , lw the memory first into a temp register
			int index;
			for(int i = 1 ;i< stack_header ; i++){
				if(Variable_List[i] == *$2){
					index = i;
					break;
				}
			}
			if(Variable_List_type[index] == "INT"){
				ss << "\t#For print_" << int2str(print_tag) << *$2 << "\n";
				ss << "\taddi " << temp_r << ", $zero , 0\n";
				ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
				ss << "\tlw " << temp_r << ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << (index*4) << "\n";
				ss << "\tli $v0 , 1\n";
				ss << "\tmove $a0, " << temp_r << "\n";
				ss << "\tsyscall\n";
			}
			else if(Variable_List_type[index] == "CHAR"){
				ss << "\t#For print_" << int2str(print_tag) << *$2 << "\n";
				ss << "\taddi " << temp_r << ", $zero , 0\n";
				ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
				ss << "\tlw " << temp_r << ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << (index*4) << "\n";
				ss << "\tli $v0 , 11\n";
				ss << "\tmove $a0, " << temp_r << "\n";
				ss << "\tsyscall\n";
			}
			print_tag++;
		}
		string forprint("");
		forprint = ss.str(); ss.str("");
		_temp += forprint;
		t_reg_index--;
		*$$ = forprint;
	}
	| READ ID {
		/* Do read command */
		//cout << "Get read command , read : " << *$2 << endl;
		// add the print MIPS (Now support read int)
		// Step 1 , find out where the ID
		int category = judge_category(*$2);
		if(category == 3){
			// array need to read in all the array
			// Step1 : Make the array[0]
			string array;
			int arr_index = 0;
			array = *$2 + "["+ int2str(arr_index) +"]";
			// Find it's size
			for(int i = 1; i < stack_header ; i++){
				if(array == Variable_List[i]){
					// Read it
					ss << "\t#For read_" << int2str(read_tag) << array << "\n";
					ss << "\tli $v0 , 5\n";
					ss << "\tsyscall\n";
					ss << "\taddi $sp , $sp , " << -(i*4) << "\n";
					ss << "\tsw  $v0, 0($sp)\n";
					ss << "\taddi $sp , $sp , " << (i*4) << "\n";
					// And then change array's name
					arr_index++;
					array = *$2 + "[" + int2str(arr_index) + "]";
					read_tag++;
				}
			}
		}
		else if(category == 2){
			// Variable , lw the memory first into a temp register
			int index;
			for(int i = 1 ;i< stack_header ; i++){
				if(Variable_List[i] == *$2){
					index = i;
					break;
				}
			}
			ss << "\t#For read_" << int2str(read_tag) << *$2 << "\n";
			ss << "\tli $v0 , 5\n";
			ss << "\tsyscall\n";
			ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
			ss << "\tsw  $v0, 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			read_tag++;
		}
		string forread("");
		forread = ss.str(); ss.str("");
		_temp += forread;
		*$$ = forread;
	}
	;

expr: unaryOp expr {
		int judge = judge_category(*$2);
		string temp("$t");
		temp += int2str(t_reg_index);
		t_reg_index++;
		if(judge == 2){ //variable
			int index = whereVariable(*$2);
			// Load the value out
			ss << "\taddi $sp , $sp , " << - (index*4) << "\n";
			ss << "\tlw " << temp << ", 0($sp)\n";
			// Judge it , if temp == 0 , we need to change it into 1
			ss << "\tbeq " << temp << ", $zero , SetOne"+int2str(un_tag)+"\n";
			// Else , set temp = 0 , and then jump to the endUn
			ss << "\taddi " << temp << ", $zero , 0\n";
			ss << "\tj EndUn"+int2str(un_tag)+"\n";
			// Add tag "SetOne"
			ss << "SetOne"+int2str(un_tag)+":\n";
			// set the temp to 1
			ss << "\taddi " << temp << ", $zero , 1\n";
			// add the tag "EndUn" , and then store it back
			ss << "EndUn"+int2str(un_tag)+":\n";
			ss << "\tsw "<< temp << ", 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
		}
		else if(judge == 3){
		}
		else if(judge == 0){//numbers
			if(*$2 == "0"){
				*$2 = "1";
			}
			else{
				*$2 = "0";
			}
		}
		else{}
		// Release temp register usage
		t_reg_index--;
		// And then return the original expr
		_temp += ss.str(); ss.str("");
		un_tag++;
		*$$ = *$2;
	}
	| NUM expr_D {
		ss << $1;
		$$ = new string(ss.str()); ss.str("");
		if($2->length() != 0)
			*$$ += ","+*$2;
	}
	| LEFT_PARENTHESE expr RIGHT_PARENTHESE expr_D {
		// base on expr_D , do the () OP NUM => With parenthese's help , do the priority
			*$$ = *$1+"," + *$2 + "," + *$3 + "," + *$4;
	}
	| ID exprIdTail {
		// Variable Assignment Here
		if($2->length() == 0)
			*$$ = *$1 + *$2;
		else
			*$$ = *$1 +","+ *$2;
	};

expr_D: /* empty */ {$$ = new string("");}
	| binOp expr {*$$ = *$1 +","+ *$2;};

exprIdTail: expr_D {*$$ = *$1;}
	| LEFT_PARENTHESE exprList RIGHT_PARENTHESE expr_D {
		*$$ = *$1+"," + *$2 + "," + *$3 +","+ *$4;}
	| LEFT_BUCKET expr RIGHT_BUCKET exprArrayTail {*$$ = *$1 + *$2 + *$3 + *$4;};

exprArrayTail: expr_D {*$$ = ","+*$1;};

exprList: /* empty */ {}
	| exprListTail { *$$ = *$1; };

exprListTail: expr exprListTail_D {*$$ = *$1 + *$2;};

exprListTail_D: /* empty */ { $$ = new string(""); }
	| DOT exprListTail { *$$ = "," + *$2; };

type: INT { $$ = 1;}
	| CHAR { $$ = 2;};

unaryOp: U_NOT {};

binOp: B_PLUS { $$ = new string("+");}
	| B_MINUS { $$= new string("-");}
	| B_MULT { $$= new string("*");}
	| B_DIVIDE  { $$= new string("/");}
	| B_EQUAL { $$= new string("==");}
	| B_ASSIGN { $$= new string("=");}
	| B_NOT_EQUAL { $$= new string("!=");}
	| B_AND { $$= new string("&&");}
	| B_OR { $$= new string("||");}
	| B_LARGER { $$= new string(">");}
	| B_SMALLER { $$= new string("<");}
	| B_NLESS_THAN { $$= new string(">=");}
	| B_NLARGER_THAN { $$= new string("<=");};

%%
void while_toMIPS(size_t while_stmt_loc , int while_stmt_size , string while_expr){
	// First , we need to judge whether if_expr is
	stringstream st(while_expr);
	string main_op;
	vector<string> Lexpr;
	vector<string> Rexpr;
	string token,for_WHILEexpr;
	int flag = 0;
	// Split out the expr
	while(getline(st, token , ',')){
		if(judge_category(token) == 1){
			if(flag == 2 || flag == 0){
				main_op = token;
				flag = 3;
			}
			else if(flag == 1){
				Lexpr.push_back(token);
			}
			else if(flag == 3){
				Rexpr.push_back(token);
			}
		}
		else if(judge_category(token) == 2 || judge_category(token) == 5 || judge_category(token) == 0){
			if(flag == 1 || flag == 0)
				Lexpr.push_back(token);
			else if(flag == 3)
				Rexpr.push_back(token); // when flag == 3
		}
		else if(token == "("){
			// Check currently stack
			if(flag == 0)
				flag = 1;
			else
				flag = 3;
		}
		else if(token == ")"){
			flag = 2;
		}
	}
	// And then make the if-exper
	if(Lexpr.size() == 1 && Rexpr.size() == 1){
		// For a Op b condition
		string L_expr = Lexpr.front();
		Lexpr.erase(Lexpr.begin());
		string R_expr = Rexpr.front();
		Rexpr.erase(Rexpr.begin());
		for_WHILEexpr = make_while_expr(main_op , L_expr , R_expr , 0);
		// Has been tested , ok
	}
	else if(Lexpr.size() >= 1 && Rexpr.size() == 0){
		// For only one expr
		string judgeData = Lexpr.front();
		int jud = judge_category(judgeData);
		string temp("$t");
		temp += int2str(t_reg_index);
		t_reg_index++;
		if(jud == 0){
			// Pure number
			ss << "\taddi " << temp << " , $zero , " << judgeData << "\n";
			ss << "\tbeq " << temp << ", 0 , EndWhile"+int2str(while_tag) << "\n";
		}
		else if(jud == 2){
			// Variable
			int index = whereVariable(judgeData);
			if(index == -1){
				// Not in this scope
				cout << "Error variable usage : " << judgeData << "; not in this scope!" << endl;
				exit(1);
			}
			ss << "\taddi $sp , $sp , " << (-index*4) << "\n";
			ss << "\tlw " << temp << " , " << " 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			ss << "\tbeq " << temp << ", 0 , EndWhile"+int2str(while_tag) << "\n";
		}
		else if(jud == 3){
			// TODO Array , need to using the following data , combine it and then search
		}
		t_reg_index--;
		for_WHILEexpr = ss.str(); ss.str("");
	}
	else{
		// Extend condition (make here more robust , here now only  a (>= , <= , < , > ) b , Extend to (expr) (> , < , <= , >=) (expr))
		// Support the while( (Lexpr) Op (Rexpr) )
		string cur_left_reg = dealWithPriority(Lexpr);
		string cur_right_reg = dealWithPriority(Rexpr);
		for_WHILEexpr = make_while_expr(main_op , cur_left_reg , cur_right_reg , 1);
		//t_reg_index -= 2;
		for_WHILEexpr = _temp_expr + for_WHILEexpr;
		_temp_expr = "";
	}
	// Now we need to insert or condition into _temp (Consider the order and the index , we insert from back to former)
	// Step 1 , insert EndWhile
	_temp.insert(while_stmt_loc + while_stmt_size,"\tj WHILE"+ int2str(while_tag) +"\nEndWhile"+int2str(while_tag)+":\n");
	// Step 2, insert for_WHILEexpr
	_temp.insert(while_stmt_loc,"WHILE"+int2str(while_tag)+":\n"+for_WHILEexpr);
}

void if_else_toMIPS(size_t if_stmt_loc , size_t else_stmt_loc , int if_stmt_size , int else_stmt_size ,string if_expr){
	// First , we need to judge whether if_expr is
	stringstream st(if_expr);
	string main_op;
	vector<string> Lexpr;
	vector<string> Rexpr;
	string token,for_IFexpr;
	int flag = 0;
	// Split out the expr
	while(getline(st, token , ',')){
		if(judge_category(token) == 1){
			if(flag == 2 || flag == 0){
				main_op = token;
				flag = 3;
			}
			else if(flag == 1){
				Lexpr.push_back(token);
			}
			else if(flag == 3){
				Rexpr.push_back(token);
			}
		}
		else if(judge_category(token) == 2 || judge_category(token) == 5 || judge_category(token) == 0){
			if(flag == 1 || flag == 0)
				Lexpr.push_back(token);
			else if(flag == 3)
				Rexpr.push_back(token); // when flag == 3
		}
		else if(token == "("){
			// Check currently stack
			if(flag == 0)
				flag = 1;
			else
				flag = 3;
		}
		else if(token == ")"){
			flag = 2;
		}
	}
	// And then make the if-exper
	if(Lexpr.size() == 1 && Rexpr.size() == 1){
		// For a Op b condition
		string L_expr = Lexpr.front();
		Lexpr.erase(Lexpr.begin());
		string R_expr = Rexpr.front();
		Rexpr.erase(Rexpr.begin());
		for_IFexpr = make_if_expr(main_op , L_expr , R_expr , 0);
		// Has been tested , ok
	}
	else if(Lexpr.size() >= 1 && Rexpr.size() == 0){
		// For only one expr
		string judgeData = Lexpr.front();
		int jud = judge_category(judgeData);
		string temp("$t");
		temp += int2str(t_reg_index);
		t_reg_index++;
		if(jud == 0){
			// Pure number
			ss << "\taddi " << temp << " , $zero , " << judgeData << "\n";
			ss << "\tbeq " << temp << ", $zero , Else"+int2str(if_tag) << "\n";
		}
		else if(jud == 2){
			// Variable
			int index = whereVariable(judgeData);
			if(index == -1){
				// Not in this scope
				cout << "Error variable usage : " << judgeData << "; not in this scope!" << endl;
				exit(1);
			}
			ss << "\taddi $sp , $sp , " << (-index*4) << "\n";
			ss << "\tlw " << temp << " , " << " 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			ss << "\tbeq " << temp << ", $zero , Else"+int2str(if_tag) << "\n";
		}
		else if(jud == 3){
			// TODO Array , need to using the following data , combine it and then search
		}
		t_reg_index--;
		for_IFexpr = ss.str(); ss.str("");
	}
	else{
		// Extend condition ( with more than 2 expr on both side)
		string cur_left_reg = dealWithPriority(Lexpr);
		string cur_right_reg = dealWithPriority(Rexpr);
		for_IFexpr = make_if_expr(main_op , cur_left_reg , cur_right_reg , 1);
		for_IFexpr = _temp_expr + for_IFexpr;
		_temp_expr = "";
	}
	// Now we need to insert or condition into _temp (Consider the order and the index , we insert from back to former)
	// Step 1 , insert Endif
	_temp.insert(else_stmt_loc+else_stmt_size,"Endif"+int2str(if_tag)+":\n");
	// Step 2, insert "\tj End if\nElse:\n" condition
	_temp.insert(else_stmt_loc,"\tj Endif"+int2str(if_tag)+"\nElse"+int2str(if_tag)+":\n");
	// Step 3 , insert for_IFexpr into the start of stmt
	_temp.insert(if_stmt_loc,for_IFexpr);
	_temp_conidtion = for_IFexpr;
}

string make_while_expr(string OP , string data1, string data2 , int data_type){
	// Transfer data1 and data2 to register mode
	string Lreg , Rreg;
	int t_usage = 0;
	if(data_type == 0){
		if(judge_category(data1) == 2){
			// Varaible , (contain array with [])
			int index = whereVariable(data1); // get mem location
			if(index == -1){
				cout << "Error , not found this variable : " << data1 << " in this scope" << endl;
				exit(1);
			}
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
			ss << "\tlw " << temp_r << ", 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			Lreg = temp_r;
		}
		else if(judge_category(data1) == 0){
			// Pure number
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi " << temp_r << ", $zero , " << data1 << "\n";
			Lreg = temp_r;
		}
		else if(judge_category(data1) == 5){
			// TODO a_reg
		}
		else{
			// TODO extend mode
		}
		// For Rreg
		if(judge_category(data2) == 2){
			// Varaible , (contain array with [])
			int index = whereVariable(data2); // get mem location
			if(index == -1){
				cout << "Error , not found this variable : " << data2 << " in this scope" << endl;
				exit(1);
			}
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
			ss << "\tlw " << temp_r << ", 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			Rreg = temp_r;
		}
		else if(judge_category(data2) == 0){
			// Pure number
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi " << temp_r << ", $zero , " << data2 << "\n";
			Rreg = temp_r;
		}
		else if(judge_category(data2) == 5){
			// TODO , if expr is a_reg
			for(int i = 0; i < a_reg_index ; i++){
				if(a_reg[i] == data2){
					Rreg = "$a"+int2str(i);
					break;
				}
			}
		}
		else{
			// TODO extend mode
		}
	}
	else if(data_type==1){
		// Input is temp register already
		Lreg = data1;
		Rreg = data2;
	}
	// ========================================Require another temp register
	string temp_j("$t");
	temp_j += int2str(t_reg_index);
	t_reg_index++;
	t_usage++;
	// Now we have Lreg and Rreg
	if(OP == "<"){
		ss << "\tslt " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // Origin: Lreg < Rreg , if yes , temp_j = 1 ,else temp_j = 0
		ss << "\tbeq " << temp_j << ", 0 , EndWhile"+int2str(while_tag)+"\n"; // If temp_j == 0 , jump to Else stmt
	}
	else if(OP == ">"){
		ss << "\tslt " << temp_j << ", " << Rreg << ", " << Lreg << "\n"; // Origin: Lreg > Rreg , if yes , temp_j = 1 ,else temp_j = 0
		ss << "\tbeq " << temp_j << ", 0 , EndWhile"+int2str(while_tag)+"\n"; // If temp_j == 0 , jump to Else stmt
	}
	else if(OP == ">="){
		ss << "\tsub " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // tempj = Lreg - Rreg
		ss << "\tbltz " << temp_j << ", EndWhile"+int2str(while_tag)+"\n";	// If temp_j < 0  , jump to Else
	}
	else if(OP == "<="){
		ss << "\tsub " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // tempj = Lreg - Rreg
		ss << "\tbgtz " << temp_j << ", EndWhile"+int2str(while_tag)+"\n";	// If temp_j > 0  , jump to Else
	}
	else if(OP == "&&"){
		// Judge Lreg , if Lreg == 0 , then jump to endwhile
		ss << "\tbeq " << Lreg << ", $zero , EndWhile"+int2str(while_tag)+"\n";
		// Judge Rreg , if Rreg == 0 , then jump to endwhile
		ss << "\tbeq " << Rreg << ", $zero , EndWhile"+int2str(while_tag)+"\n";
	}
	else if(OP == "||"){
		// Judge Lreg , if Lreg == 1 , then jump to the tag we add (on the end of this expr , which concat with the while-stmt)
		ss << "\tbeq " << Lreg << ", 1 , goWHILE"+int2str(while_tag)+"\n";
		// Judge Rreg , mention that , if we run to this code , it means now Lreg = 0 , so when Rreg = 0 , it need to go to endwhile
		ss << "\tbeq " << Rreg << ", 0 , EndWhile"+int2str(while_tag)+"\n";
		// At the end , we add the tag which the above statement can jump
		ss << "goWHILE"+int2str(while_tag)+":\n";
	}
	else if(OP == "!="){
		ss << "\tbeq " << Lreg << ", " << Rreg << ", EndWhile"+int2str(while_tag)+"\n";
	}
	else if(OP == "=="){
		ss << "\tbne " << Lreg << ", " << Rreg << ", EndWhile"+int2str(while_tag)+"\n";
	}
	else{
		// Not in condition
		cout << "Error while expr , with no found " << OP << " in our operator rules" << endl;
		exit(1);
	}

	// Release the temp register
	t_reg_index -= t_usage;
	// store ss
	string result = ss.str();
	ss.str("");
	return result;
}

string make_if_expr(string OP , string data1, string data2 , int data_type){
	// Transfer data1 and data2 to register mode
	string Lreg , Rreg;
	int t_usage = 0;
	if(data_type == 0){
		if(judge_category(data1) == 2){
			// Varaible , (contain array with [])
			int index = whereVariable(data1); // get mem location
			if(index == -1){
				cout << "Error , not found this variable : " << data1 << " in this scope" << endl;
				exit(1);
			}
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
			ss << "\tlw " << temp_r << ", 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			Lreg = temp_r;
		}
		else if(judge_category(data1) == 0){
			// Pure number
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi " << temp_r << ", $zero , " << data1 << "\n";
			Lreg = temp_r;
		}
		else if(judge_category(data1) == 5){
			// TODO a_reg
			for(int i = 0; i < a_reg_index ; i++){
				if(a_reg[i] == data1){
					Lreg = "$a"+int2str(i);
					break;
				}
			}
		}
		else{
			// TODO extend mode
		}
		// For Rreg
		if(judge_category(data2) == 2){
			// Varaible , (contain array with [])
			int index = whereVariable(data2); // get mem location
			if(index == -1){
				cout << "Error , not found this variable : " << data2 << " in this scope" << endl;
				exit(1);
			}
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi $sp , $sp , " << -(index*4) << "\n";
			ss << "\tlw " << temp_r << ", 0($sp)\n";
			ss << "\taddi $sp , $sp , " << (index*4) << "\n";
			Rreg = temp_r;
		}
		else if(judge_category(data2) == 0){
			// Pure number
			string temp_r("$t");
			temp_r += int2str(t_reg_index);
			t_reg_index++;
			t_usage++;
			ss << "\taddi " << temp_r << ", $zero , " << data2 << "\n";
			Rreg = temp_r;
		}
		else if(judge_category(data2) == 5){
			// TODO , if expr is a_reg
			for(int i = 0; i < a_reg_index ; i++){
				if(a_reg[i] == data2){
					Rreg = "$a"+int2str(i);
					break;
				}
			}
		}
		else{
			// TODO extend mode (expr with another expr condition)
		}
	}
	else if(data_type == 1){
		Lreg = data1;
		Rreg = data2;
	}
	// ==================================== Require another temp register , do the translate
	string temp_j("$t");
	temp_j += int2str(t_reg_index);
	t_reg_index++;
	t_usage++;
	// Now we have Lreg and Rreg
	if(OP == "<"){
		ss << "\tslt " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // Origin: Lreg < Rreg , if yes , temp_j = 1 ,else temp_j = 0
		ss << "\tbeq " << temp_j << ", 0 , Else"+int2str(if_tag)+"\n"; // If temp_j == 0 , jump to Else stmt . FIXME , Else tag need to be unique
	}
	else if(OP == ">"){
		ss << "\tslt " << temp_j << ", " << Rreg << ", " << Lreg << "\n"; // Origin: Lreg < Rreg , if yes , temp_j = 1 ,else temp_j = 0
		ss << "\tbeq " << temp_j << ", 0 , Else"+int2str(if_tag)+"\n"; // If temp_j == 0 , jump to Else stmt . FIXME , Else tag need to be unique
	}
	else if(OP == ">="){
		ss << "\tsub " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // tempj = Lreg - Rreg
		ss << "\tbltz " << temp_j << ", Else"+int2str(if_tag)+"\n";	// If temp_j < 0  , jump to Else
	}
	else if(OP == "<="){
		ss << "\tsub " << temp_j << ", " << Lreg << ", " << Rreg << "\n"; // tempj = Lreg - Rreg
		ss << "\tbgtz " << temp_j << ", Else"+int2str(if_tag)+"\n";	// If temp_j > 0  , jump to Else
	}
	else if(OP == "&&"){
		// Judge Lreg , if Lreg == 0 , then jump to else
		ss << "\tbeq " << Lreg << ", $zero , Else"+int2str(if_tag)+"\n";
		// Judge Rreg , if Rreg == 0 , then jump to else
		ss << "\tbeq " << Rreg << ", $zero , Else"+int2str(if_tag)+"\n";
	}
	else if(OP == "||"){
		// Judge Lreg , if Lreg == 1 , then jump to the tag we add (on the end of this expr , which concat with the if-stmt)
		ss << "\tbeq " << Lreg << ", 1 , goIf"+int2str(if_tag)+"\n";
		// Judge Rreg , mention that , if we run to this code , it means now Lreg = 0 , so when Rreg = 0 , it need to go to endwhile
		ss << "\tbeq " << Rreg << ", 0 , Else"+int2str(if_tag)+"n";
		// At the end , we add the tag which the above statement can jump
		ss << "goIf"+int2str(if_tag)+":\n";
	}
	else if(OP == "!="){
		ss << "\tbeq " << Lreg << ", " << Rreg << ", Else"+int2str(if_tag)+"\n";
	}
	else if(OP == "=="){
		ss << "\tbne " << Lreg << ", " << Rreg << ", Else"+int2str(if_tag)+"\n";
	}
	else{
		// Not in condition
		cout << "Error if expr , with no found " << OP << " in our operator rules" << endl;
		exit(1);
	}

	// Release the temp register
	t_reg_index -= t_usage;
	// store ss
	string result = ss.str();
	ss.str("");
	return result;
}

void dealing_Expr(){
	vector<string> Data_stack;
	vector<string> Op_stack;
	string L_str;
	int flag = 0,store_index = 0,reverse_flag = 0; // With reverse_flag == 1 , all - and / need to using Data_stack with a reverse (Pop 2 element out of Data stack , and then using the latter first)
	// First , check the Lvalue
	for(vector<string>::iterator i = array_list.begin() ; i != array_list.end() ; i++){
		if(Lvalue_list[0] == *i){
			L_str = Lvalue_list[0]+Lvalue_list[1];
			break;
		}
	}
	for(int k = stack_tailer; k < stack_header ; k++){
		if(Variable_List[k] == L_str){
			flag = 1;
			store_index = k; // For
			break;
		}
	}
	if(flag == 1){
		// Confirm that Lvalue is an Array
		// cout << "+++++ Found in Variable_List (Arr): " << L_str << endl;
	}
	else{
		// Check if it is Global
		for(int k = 1 ; k < stack_global ; k++){
			if(Variable_List[k] == Lvalue_list[0]){
				flag = 2;
				store_index = k;
				break;
			}
		}
		// Check out if it is a Variable
		for(int k = stack_tailer ; k < stack_header ; k++){
			if(Variable_List[k] == Lvalue_list[0]){
				flag = 2;
				store_index = k;
				break;
			}
		}
		if(flag == 2){
			//cout << "+++++ Found in Variable_List (Var): " << Lvalue_list[0] << endl;
		}
		else{
			// Search whether it is in the a_reg
			for(int i = 0 ; i < a_reg_index ; i++){
				if(a_reg[i] == Lvalue_list[0]){
					// Find it , change flag to 3 (A_reg mode)
					flag = 3;
					store_index = i;
					break;
				}
			}
			if(flag == 0){
				cout << "Error with lvalue , which not existed: " << Lvalue_list[0] << endl;
				exit(1);
			}
		}
	}

	// And now , we can dealing with Right side
	int Op_change_flag = 0;
	for(vector<string>::iterator i = Rvalue_list.begin(); i != Rvalue_list.end() ; i++){
		//cout << "Right value judge: " << judge_category(*i) << endl;
		int judge = judge_category(*i);
		/* TODO : Whether it comes with one data match one OP ? */
		if(judge == 4){
			// Function , find out the parameter , and function name , go together and then translate to assembly code
			string func_name = *i;
			i = i+2;
			vector<string> p_list;
			while(*i!=")"){
				// Those are parameter List
				p_list.push_back(*i);
				i++;
			}
			if(p_list.size() <= 4){
				// Write assembly , pass those parameter into a_reg , and then call the function call
				for(vector<string>::iterator k = p_list.begin(); k != p_list.end(); k++){
					int p_jud = judge_category(*k);
					if(p_jud == 3){
						// This is an array
						string temp_data = *k + *(k+1);
						++k;
						// Search its stack location
						int jud = whereVariable(temp_data);
						if(jud == -1){
							cout << "Error , not found this variable : " << temp_data << " in this scope" << endl;
							exit(1);
						}
						if(jud != -1){
							ss << "\taddi $sp , $sp , " << -(jud*4) << "\n";
							ss << "\tlw $a"<< a_reg_index << " , 0($sp)\n";
							ss << "\taddi $sp , $sp , " << (jud*4) << "\n";
							_temp_expr += ss.str(); ss.str("");
							a_reg_index++;
						}
						else{
							cout << "Error parameter :"<< temp_data << endl;
							exit(1);
						}
					}
					else if(p_jud == 2){
						// This is an variable
						int jud = whereVariable(*k);
						if(jud == -1){
							cout << "Error , not found this variable : " << *k << " in this scope" << endl;
							exit(1);
						}
						if(jud != -1){
							ss << "\taddi $sp , $sp ," << -(jud*4) << "\n";
							ss << "\tlw $a"<< a_reg_index << " , 0($sp)\n";
							ss << "\taddi $sp , $sp ," << (jud*4) << "\n";
							_temp_expr += ss.str(); ss.str("");
							a_reg_index++;
						}
						else{
							cout << "Error parameter :"<< *k << endl;
							exit(1);
						}
					}
					else if(p_jud == 0){
						// Pure number
						ss << "\taddi $a"<< a_reg_index << " , $a"<< a_reg_index <<" ," << *k << "\n";
						_temp_expr += ss.str(); ss.str("");
						a_reg_index++;
					}
				}
				a_reg_index = 0;
			}
			// After we have push parameter into a_reg , we can make the function call
			ss << "\tjal " << func_name << "\n";
			_temp_expr += ss.str(); ss.str("");
			// And then push an "specific" number into the Data_stack , to tell the expr dealer to know , with this specific number , using "$v0" as instead
			Data_stack.push_back("$v0");

		}
		else if(judge == 3){
			// Array , merge the following token and then store into Data stack;
			string array = *i + *(i+1);
			++i;
			// push into Data stack
			Data_stack.push_back(array);
		}
		else if(judge == 1){
			// Op , pop out the op stack , see whether the top of stack's priority
			if(Op_stack.size() == 0){
				// Now it's empty , push straightly
				Op_stack.push_back(*i);
			}
			else{
				// and do the correspondence move , and then push back into it
				string in_top = Op_stack.back();
				int jud = judgeOp(*i,in_top);
				if(jud == 0 || jud == 3){
					if(Op_change_flag == 0){
						// Nothing to do
						Op_stack.push_back(*i);
					}
					else if(Op_change_flag == 1){
						// Pop out the last one
						//string last_data = Data_stack.back();
						//Data_stack.erase(Data_stack.end());
						// Reverse all stack
						reverse(Op_stack.begin(),Op_stack.end());
						reverse(Data_stack.begin(),Data_stack.end());
						// And then add *i in Op
						//Data_stack.push_back(last_data);
						Op_stack.push_back(*i);
						reverse_flag = !reverse_flag;
						Op_change_flag = 0;
					}
				}
				else if(jud == 1){
					// Keep current Op flag
					Op_stack.push_back(*i);
				}
				else if(jud == 2){
					// *i win
					Op_stack.push_back(*i);
					Op_change_flag = 1;
				}
			}
		}
		else if(judge == 2 || judge == 0){
			// Variable (2) or Pure Number(0) or a_reg(5), Push into Data stack
			if((judge == 2) && whereVariable(*i) == -1){
				cout << "Error , not found this variable : " << *i << " in this scope" << endl;
				exit(1);
			}
			Data_stack.push_back(*i);
		}
		else if(judge == 5){
			// Parse it to a_reg
			Data_stack.push_back(*i);
		}
		else{
			//: if i == "(" , whether those Op , and Data push in Stack directly <= Highest Priority
			if(*i == "("){
				// Need to push those variable into stack top
				++i;
				vector<string> priority;
				while(*i != ")"){
					/* TODO: Dealing with the nested "(" and ")" */
					priority.push_back(*i);
					i++;
				}
				//	skip the ")"
				string temp_reg = dealWithPriority(priority); // Record the temp register
				//
				Data_stack.push_back(temp_reg);
			}
			else{
				// Not found , exit
				cout << "Error Right Value: " << *i << endl;
				debugVector(function_list);
				exit(1);
			}
		}
	}
	// Check Op_change_flag , if  = 1 , need to reverse all
	if(Op_change_flag == 1){
		reverse(Op_stack.begin(),Op_stack.end());
		reverse(Data_stack.begin(),Data_stack.end());
		reverse_flag = !reverse_flag;
	}
	// Debug : pop out all Op and Data stack
	cout << "Pop out Data stack : ";
	debugVector(Data_stack);
	cout << "Pop out OP stack : ";
	debugVector(Op_stack);
	//cout << "And Now , reverse flag = " << reverse_flag << endl;
	// After we have Data_stack and Op_stack , we can do it (remember $tx and $ax and $vx , while $ax is using it's own name)
	string L_reg("$t");
	L_reg += int2str(t_reg_index);
	t_reg_index++;
	ss << "\t#Assignment\n";
	ss << "\taddi "<< L_reg << ", $zero, 0 \n";
	while(Data_stack.size()>=1){
		string data1,data2;
		if(Data_stack.size()>=2){
			data1 = Data_stack.front();
			Data_stack.erase(Data_stack.begin());
			data2 = Data_stack.front();
			Data_stack.erase(Data_stack.begin());
			ss << "\t#With Data1:"<<data1<<", Data2:"<<data2<<", Op:"<< Op_stack.front() <<"\n";
			if(!Op_stack.empty()){
			// When the Op isn't empty , we need to pop out data to do
				if(reverse_flag==0){
					trans_code2MIPS(Op_stack.front(),data1,data2,L_reg);
					Op_stack.erase(Op_stack.begin());
				}
				else if(reverse_flag ==1){
					if((Op_stack.front() == "-" && Op_stack.size() > 1) || Op_stack.front() == "/"){
						trans_code2MIPS(Op_stack.front(),data2,data1,L_reg);
						Op_stack.erase(Op_stack.begin());
					}
					else{
						trans_code2MIPS(Op_stack.front(),data1,data2,L_reg);
						Op_stack.erase(Op_stack.begin());
					}
					//trans_code2MIPS(Op_stack.front(),data1,data2,L_reg);
					//Op_stack.erase(Op_stack.begin());
				}
			Data_stack.insert(Data_stack.begin(),L_reg);
			}
		}
		else if(Data_stack.size()==1){
			data1 = Data_stack.front();
			if(!Op_stack.empty() && (Data_stack.front() != L_reg)){
				ss << "\t#With Data1:"<<data1<<", Op:"<<Op_stack.front()<<"\n";
				trans_code2MIPS(Op_stack.front(),data1,L_reg,L_reg);
			}
			else if(Op_stack.size()==0 && (Data_stack.front())!= L_reg){
				// Do the add directly (Like $v0)
				if(judge_category(Data_stack.front()) == 2){
					int index = whereVariable(Data_stack.front());
					if(index == -1){
						cout << "Error with scope problem : " << Data_stack.front() << ", not in this scope!" << endl;
					}
					string temp_reg("$t");
					temp_reg += int2str(t_reg_index);
					ss << "\t#With Data1:"<<data1<<",which no Op\n";
					ss << "\taddi $sp , $sp , " << -index*4 << "\n";
					ss << "\tlw " << temp_reg << ", 0($sp)\n";
					ss << "\taddi $sp , $sp , " << index*4 << "\n";
					ss << "\tadd " << L_reg << ", "<< L_reg << ", " << temp_reg << "\n";
					_temp_expr += ss.str(); ss.str("");
				}
				else if(judge_category(Data_stack.front()) == 0){
					ss << "\t#With Data1:"<<data1<<",which no Op\n";
					ss << "\tadd " << L_reg << ", "<< L_reg << ", " << data1 << "\n";
					_temp_expr += ss.str(); ss.str("");
				}
				else if(judge_category(Data_stack.front()) == 5){
					// I'm a_reg , find it
					for(int i = 0 ; i < a_reg_index ; i++){
						if(a_reg[i] == data1)
							data1 = "$a"+ int2str(i);
					}
					ss << "\t#With argument assignment:" << data1 << ",which no OP\n";
					ss << "\tadd " << L_reg << ", " << L_reg << ", " << data1 << "\n";
					_temp_expr += ss.str(); ss.str("");
				}
				else if(data1 == "$v0"){
					// Return value
					ss << "\t#With return value :" << data1 << ",which no OP\n";
					ss << "\tadd " << L_reg << ", " << L_reg << ", " << data1 << "\n";
					_temp_expr += ss.str(); ss.str("");
				}
			}
			Data_stack.erase(Data_stack.begin());
		}
	}
	//cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~store index = " << store_index << endl;
	if(flag == 1 || flag == 2){
		// Assign the L_reg to the Lvalue storage location
		ss << "\taddi $sp , $sp ," << -(store_index*4)<< "\n";
		ss << "\tsw " << L_reg << ", 0($sp)\n";
		ss << "\taddi $sp , $sp ," << (store_index*4)<< "\n";
		_temp_expr += ss.str(); ss.str("");
	}
	else if(flag == 3){
		// Left value is a_reg
		ss << "\tadd " << "$a"+int2str(store_index) << ", $zero , " << L_reg << "\n";
		_temp_expr += ss.str(); ss.str("");
	}
	// At Least , clean out the vector
	if(t_reg_index != 0)
		t_reg_index--;
	Lvalue_list.clear();
	Rvalue_list.clear();
}

string dealWithPriority(vector<string> List){
	vector<string> Data;
	vector<string> Op;
	int Op_flag = 0;
	int reverse_flag = 0;
	// Find out those data and Op in List
	for(vector<string>::iterator i = List.begin(); i != List.end() ; i++){
		int judge = judge_category(*i);
		/* FIXME : do the array condition : array[] , and down below */
		/* Here is in the ( ... ) , I simply do only pure number and variable here , and without nested structure*/
		if(judge == 2 || judge == 0){
			// Variable , push in Data
			if((judge == 2) && whereVariable(*i) == -1){
				cout << "Error , not found this variable : " << *i << " in this scope" << endl;
				exit(1);
			}
			Data.push_back(*i);
		}
		else if(judge == 1){
			// Operator
			if(Op.size() == 0){
				// Now it's empty , push straightly
				Op.push_back(*i);
			}
			else{
				// and do the correspondence move , and then push back into it
				string in_top = Op.back();
				int jud = judgeOp(*i,in_top);
				if(jud == 0 || jud == 3){
					// Pop out the last one
					//string last_data = Data.back();
					//Data.erase(Data.end());
					// No need to do anything , push *i ( which 0 declare as don't care)
					reverse(Op.begin(),Op.end());
					reverse(Data.begin(),Data.end());
					// And then add *i in Op
					//Data.push_back(last_data);
					Op.push_back(*i);
					reverse_flag = !reverse_flag;
					Op_flag = 0;
				}
				else if(jud == 1){
					Op.push_back(*i);
				}
				else if(jud == 2){
					Op.push_back(*i);
					Op_flag = 1;
				}
			}
		}
	}
	if(Op_flag == 1){
		reverse(Op.begin(),Op.end());
		reverse(Data.begin(),Data.end());
		reverse_flag = !reverse_flag;
	}

	// Step 1 : Initialize temp register
	string current_t_reg("$t");
	current_t_reg += int2str(t_reg_index);
	t_reg_index++;
	ss << "\taddi "<< current_t_reg << ", $zero , 0 \n";
	while(Data.size() >= 1){
		string data1,data2;
		if(Data.size()>=2){
			data1 = Data.front();
			Data.erase(Data.begin());
			data2 = Data.front();
			Data.erase(Data.begin());
			if(!Op.empty()){
				// When the Op isn't empty , we need to pop out data to do
				//cout << "OP:" << Op.front() << "; Data1:"<< data1 << "; Data2:" << data2 << "; current_register:" << current_t_reg << endl;
				if(reverse_flag==0){
					trans_code2MIPS(Op.front(),data1,data2,current_t_reg);
					Op.erase(Op.begin());
				}
				else if(reverse_flag ==1){
					if((Op.front() == "-"  && Op.size() > 1) || Op.front() == "/"){
						trans_code2MIPS(Op.front(),data2,data1,current_t_reg);
						Op.erase(Op.begin());
					}
					else{
						trans_code2MIPS(Op.front(),data1,data2,current_t_reg);
						Op.erase(Op.begin());
					}
					//trans_code2MIPS(Op.front(),data1,data2,current_t_reg);
					//Op.erase(Op.begin());
				}
				Data.insert(Data.begin(),current_t_reg);
			}
		}
		else if(Data.size()==1){
			data1 = Data.front();
			Data.erase(Data.begin());
			if(!Op.empty() && (Data.front()!=current_t_reg)){
				trans_code2MIPS(Op.front(),data1,current_t_reg,current_t_reg);
			}
			else if(Op.empty() && (Data.front()!=current_t_reg)){
				// When input data has only one data , find out this data and then store into current_t_reg
				trans_var2MIPS(data1,current_t_reg);
			}
		}
	}
	_temp_expr += ss.str(); ss.str("");
	return current_t_reg;
}

void trans_var2MIPS(string data , string current_register){
	int t_usage = 0;
	string reg1;
	if(judge_category(data) == 2){
		for(int i = 0 ; i < stack_header ; i++){
			if(Variable_List[i] == data){
				reg1 = "$t"+int2str(t_reg_index);
				t_reg_index++;
				int index = i*4;
				// and now load it into temp register
				ss << "\taddi $sp , $sp , " << -index << "\n";
				ss << "\tlw "<< reg1 << ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << index << "\n";
				t_usage++;
				break;
			}
		}
	}
	else if(judge_category(data) == 5){
		for(int i = 0; i < a_reg_index ; i++){
			if(a_reg[i] == data){
				reg1 = "$a"+int2str(i);
				break;
			}
		}
	}
	else if(judge_category(data)== 0){
		// Pure number , and then we load it into reg1
		reg1 = "$t"+int2str(t_reg_index);
		t_reg_index++;
		t_usage++;
		ss << "\taddi "<<reg1 << ", $zero , 0\n";
		ss << "\taddi "<<reg1 << ", "<<reg1<<" , "<< data << "\n";
	}
	// ===============================  Do the assignment
	ss << "\taddi " << current_register << " , " << reg1 << ", 0\n";
	t_reg_index -= t_usage;
}

void trans_code2MIPS(string OP,string Data1,string Data2 ,string current_register){
	// Debug
	cout << "OP:" << OP << "; Data1:"<< Data1 << "; Data2:" << Data2 << "; current_register:" << current_register << endl;
	// And now we can put it into the assembly code
	// Transfer the Data1 , and Data2 to stack mode
	int t_usage = 0;
	string reg1,reg2;
	// For data1 convert
	if(judge_category(Data1)==2){
		for(int i = 0 ; i < stack_header ; i++){
			if(Variable_List[i] == Data1){
				reg1 = "$t"+int2str(t_reg_index);
				t_reg_index++;
				int index = i*4;
				// and now load it into temp register
				ss << "\taddi $sp , $sp , " << -index << "\n";
				ss << "\tlw "<< reg1 << ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << index << "\n";
				t_usage++;
				break;
			}
		}
	}
	else if(Data1 == "$v0" || Data1 == current_register || (Data1.find("$t") == 0) ){ // Because need to push the result back to keep calculate
		reg1 = Data1;
	}
	else if(judge_category(Data1) == 5){
		for(int i = 0; i < a_reg_index ; i++){
			if(a_reg[i] == Data1){
				reg1 = "$a"+int2str(i);
				break;
			}
		}
	}
	else if(judge_category(Data1)== 0){
		// Pure number , and then we load it into reg1
		reg1 = "$t"+int2str(t_reg_index);
		t_reg_index++;
		t_usage++;
		ss << "\taddi "<<reg1 << ", $zero , 0\n";
		ss << "\taddi "<<reg1 << ", "<<reg1<<" , "<< Data1 << "\n";
	}
	// For data2 convert
	if(judge_category(Data2)==2){
		for(int i = 0 ; i < stack_header ; i++){
			if(Variable_List[i] == Data2){
				reg2 = "$t"+int2str(t_reg_index);
				t_reg_index++;
				int index = i*4;
				t_usage++;
				// and now load it into temp register
				ss << "\taddi $sp , $sp , " << -index << "\n";
				ss << "\tlw "<< reg2<< ", 0($sp)\n";
				ss << "\taddi $sp , $sp , " << index << "\n";
				break;
			}
		}
	}
	else if(Data2 == "$v0" || Data2 == current_register || (Data2.find("$t") == 0)){
		reg2 = Data2;
	}
	else if(judge_category(Data2) == 5){
		for(int i = 0; i < a_reg_index ; i++){
			if(a_reg[i] == Data2){
				reg2 = "$a"+int2str(i);
				break;
			}
		}
	}
	else if(judge_category(Data2)== 0){
		// Pure number , and then we load it into reg1
		reg2 = "$t"+int2str(t_reg_index);
		t_reg_index++;
		t_usage++;
		ss << "\taddi "<<reg2 << ", $zero , 0\n";
		ss << "\taddi "<<reg2 << ", "<<reg2<<" , "<< Data2 << "\n";
	}

	// For Op
	if(OP == "*"){
		ss << "\tmult " << reg1 << ", " << reg2 <<"\n";
		ss << "\tmflo " << current_register << "\n"; // FIXME : Pretend this is always in low
	}
	else if(OP == "/"){
		ss << "\tdiv " << reg1 << "," << reg2 << "\n";
		ss << "\tmflo " << current_register << "\n"; // FIXME : Pretend this is always in low
	}
	else if(OP == "+"){
		ss << "\tadd " << current_register << ", " << reg1 << ", " << reg2 << "\n";
	}
	else if(OP == "-"){
		ss << "\tsub " << current_register << ", " << reg1 << ", " << reg2 << "\n";
	}
	else{
		// TODO Another Operation
	}

	t_reg_index -= t_usage;
}

int judge_category(string ID){
  //array
	for(vector<string>::iterator i = array_list.begin() ; i != array_list.end() ; i++){
		if(ID == *i){
			return 3;
		}
	}
	//variable
	for(int i = 0 ; i < stack_header ; i++){
		if(Variable_List[i] == ID){
			return 2;
		}
	}
	//function
	for(vector<string>::iterator i = function_list.begin() ; i != function_list.end() ; i++){
		if(ID == *i){
			return 4;
		}
	}
	// operation
	if(ID == "+" || ID == "-" || ID == "*" || ID == "/" || ID == "==" || ID == "!=" || ID == "&&" || ID == "||" || ID == ">" || ID == "<" || ID == ">=" || ID == "<=" ){
		return 1;
	}
	//function parameter's
	for(int i = 0; i < a_reg_index ; i++){
		if(a_reg[i] == ID)
			return 5;
	}
	// Judge whether it is pure number
	int p_flag = 0;
	for(int i = 0; i < (int)ID.size() ; i++){
		if(isdigit((ID.c_str()[i]))){
      p_flag = 0;
		}
		else {
			p_flag = 1;
		}
	}
	if(p_flag == 0){
		return 0;
	}
	// All not found
	return -1;
}

int judgeOp(string OP1 , string OP2){
	// Judge whether OP1 and OP2 's relationships , if OP1 or OP2 are not +-*/ , return 0
	if(OP1 == "*" || OP1 == "/"){
		if(OP2 == "*" || OP2 == "/"){
			// same priority , return 1
			return 1;
		}
		else if(OP2 == "+" || OP2 == "-"){
			// OP1 win , return 2
			return 2;
		}
		else{
			return 0;
		}
	}
	else if(OP1 == "+" || OP1 == "-"){
		if(OP2 == "*" || OP2 == "/"){
			// OP2 win , return 3
			return 3;
		}
		else if(OP2 == "+" || OP2 == "-"){
			//same priority , return 1
			return 1;
		}
		else{
			return 0;
		}
	}
	else{
		return 0;
	}
}

int push_stack(int type , string ID , int size , int ID_type){

	if(type == 0){//variable
		if(search_duplicate(ID)==1){ //does not exist in stack add new
			Variable_List[stack_header] = ID;
			if( ID_type == 0){ //int
				Variable_List_type[stack_header] = "INT";
			}
			else if( ID_type == 1){//char
				Variable_List_type[stack_header] = "CHAR";
			}
			ss << "\t#" << ID << " is in " << stack_header*4 <<"($sp)\n";
			ss << "\taddi $sp , $sp , "<< -4*stack_header<<"\n";
			ss << "\taddi $t0 , $zero , 0\n";
			ss << "\tsw $t0 , 0($sp)\n";
			ss << "\taddi $sp , $sp , "<< 4*stack_header << "\n";
			_temp += ss.str(); ss.str("");
			stack_header++;
		}
		else{
			cout << ID <<", variable existed!" <<endl;
			exit(1);
		}
	}

  else{ //array
  if(search_duplicate(ID)==1){
			for(int i = stack_header ; i < stack_header + size ; i++){
				ss << i - stack_header;
				Variable_List[i] = ID+"["+ss.str()+"]";
        ss.str("");
				if( ID_type == 0){//int
					Variable_List_type[i] = "INT";
				}
				else if( ID_type == 1){//char
					Variable_List_type[i] = "CHAR";
				}
			}
			ss << "\t#From "<<stack_header*4<<"($sp) to "<<(stack_header+size)*4<<"($sp) now is occupied by"<< ID <<"[]\n";
			_temp += ss.str();
      ss.str("");
			stack_header+=size;
		}
		else{
			cout << ID <<", array existed!" <<endl;
			exit(1);
		}
	}
	return 0;
}

int whereVariable(string ID){
	for(int i = stack_tailer; i < stack_header ; i++){
		if(Variable_List[i] == ID && Variable_List[i].size() > 0)
			return i;
	}
	for(int i = 1 ; i < stack_global ; i++){
		if(Variable_List[i] == ID)
			return i;
	}

	return -1;
}

int search_duplicate(string ID){
	for(int i = stack_tailer; i < stack_header;i++ ){
		if(Variable_List[i] == ID){
			return 0;
		}
	}
	return 1;
}

string int2str(int &i){
	string s;
	stringstream conv(s);
	conv << i;
	return conv.str();
}

void debugVector(vector<string> stack){
	for(vector<string>::iterator i = stack.begin() ; i != stack.end() ; i ++){
		cout<< *i << "\t";
	}
	cout << endl;
}

int yyerror(string s) {
	extern int yylineno;
	extern char **yytext;
	cerr << "ERROR: " << s << " at symbol \"" << (yytext);
	cerr << "\" on line " << yylineno << endl;
	return 0;
}

int yyerror(char *s) {
	return yyerror(string(s));
}

int yyerror() {
	return yyerror(string(""));
}
