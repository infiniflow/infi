
%{
#include <stdint.h>
#include <stdio.h>
#include "parser.h"
#include "lexer.h"

void yyerror(YYLTYPE * llocp, void* lexer, infinity::ParserResult* result, const char* msg);
%}

%code requires {

#include "expression.h"
#include "parser_result.h"
#include "defer_operation.h"
#include "statement/alter_statement.h"
#include "statement/copy_statement.h"
#include "statement/create_statement.h"
#include "statement/delete_statement.h"
#include "statement/drop_statement.h"
#include "statement/execute_statement.h"
#include "statement/explain_statement.h"
#include "statement/flush_statement.h"
#include "statement/optimize_statement.h"
#include "statement/insert_statement.h"
#include "statement/prepare_statement.h"
#include "statement/select_statement.h"
#include "statement/show_statement.h"
#include "statement/update_statement.h"
#include "statement/command_statement.h"
#include "statement/compact_statement.h"
#include "table_reference/base_table_reference.h"
#include "table_reference/join_reference.h"
#include "table_reference/cross_product_reference.h"
#include "table_reference/table_reference.h"
#include "table_reference/subquery_reference.h"
#include "parser_helper.h"

#include <vector>

#define YYSTYPE SQLSTYPE
#define YYLTYPE SQLLTYPE

struct SQL_LTYPE {
    int first_line;
    int first_column;
    int last_line;
    int last_column;

    int total_column;
    int string_length;

    std::vector<void*> parameters;
};

#define SQLLTYPE SQL_LTYPE
#define SQLLTYPE_IS_DECLARED 1

#define YY_USER_ACTION \
    yylloc->first_line = yylloc->last_line;      \
    yylloc->first_column = yylloc->last_column;  \
    for(int i = 0; yytext[i] != '\0'; ++ i) {   \
        yylloc->total_column++;                   \
        yylloc->string_length++;                  \
        if (yytext[i] == '\n') {                  \
            yylloc->last_line++;                    \
            yylloc->last_column = 0;                \
        } else {                                  \
            yylloc->last_column++;                  \
        }                                         \
    }
}


%define api.pure full

%define parse.trace
%define parse.error verbose

%define api.prefix {sql}

%lex-param {void *scanner}
%parse-param {void *scanner} {infinity::ParserResult* result}

%locations
%initial-action {
  // Initialize
  @$.first_column = 0;
  @$.last_column = 0;
  @$.first_line = 0;
  @$.last_line = 0;
  @$.total_column = 0;
  @$.string_length = 0;
};

%code{
// Avoid warnings with the error counter.
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
}

%union {
    bool    bool_value;
    char*   str_value;
    double  double_value;
    int64_t long_value;

    infinity::BaseStatement*   base_stmt;
    infinity::SelectStatement* select_stmt;
    infinity::CopyStatement*   copy_stmt;
    infinity::InsertStatement* insert_stmt;
    infinity::UpdateStatement* update_stmt;
    infinity::DeleteStatement* delete_stmt;
    infinity::CreateStatement* create_stmt;
    infinity::DropStatement*   drop_stmt;
    infinity::PrepareStatement* prepare_stmt;
    infinity::ExecuteStatement* execute_stmt;
    infinity::AlterStatement*   alter_stmt;
    infinity::ShowStatement*    show_stmt;
    infinity::ExplainStatement* explain_stmt;
    infinity::FlushStatement*  flush_stmt;
    infinity::OptimizeStatement*  optimize_stmt;
    infinity::CommandStatement* command_stmt;
    infinity::CompactStatement* compact_stmt;

    std::vector<infinity::BaseStatement*>* stmt_array;

    std::vector<infinity::TableElement*>*  table_element_array_t;
    infinity::TableElement*           table_element_t;
    infinity::ColumnDef*              table_column_t;
    infinity::ColumnType              column_type_t;
    infinity::ConstraintType          column_constraint_t;
    std::set<infinity::ConstraintType>* column_constraints_t;
    std::vector<std::string>*         identifier_array_t;
    infinity::TableConstraint*        table_constraint_t;

    infinity::BaseTableReference*     table_reference_t;
    infinity::TableAlias *            table_alias_t;
    infinity::JoinType                join_type_t;

    infinity::OrderByExpr*            order_by_expr_t;
    std::vector<infinity::OrderByExpr*>*   order_by_expr_list_t;
    infinity::OrderType               order_by_type_t;

    infinity::WithExpr*               with_expr_t;
    std::vector<infinity::WithExpr*>*      with_expr_list_t;

    infinity::SetOperatorType         set_operator_t;

    infinity::ExplainType             explain_type_t;

    infinity::ParsedExpr*             expr_t;
    infinity::ConstantExpr*           const_expr_t;
    std::vector<infinity::ParsedExpr*>*    expr_array_t;
    std::vector<std::vector<infinity::ParsedExpr*>*>*    expr_array_list_t;

    std::vector<infinity::WhenThen*>*     case_check_array_t;

    infinity::UpdateExpr*             update_expr_t;
    std::vector<infinity::UpdateExpr*>*    update_expr_array_t;

    infinity::TableName* table_name_t;
    infinity::CopyOption* copy_option_t;
    std::vector<infinity::CopyOption*>* copy_option_array;

    infinity::InitParameter*        index_param_t;
    std::vector<infinity::InitParameter*>* index_param_list_t;
    std::vector<infinity::InitParameter*>* with_index_param_list_t;

    std::vector<infinity::IndexInfo*>* index_info_list_t;

    // infinity::IfExistsInfo*        if_exists_info_t;
    infinity::IfNotExistsInfo*     if_not_exists_info_t;

    std::pair<int64_t, int64_t>*    int_sparse_ele_t;
    std::pair<int64_t, double>*     float_sparse_ele_t;
}

%destructor {
    fprintf(stderr, "destroy index info list\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <index_info_list_t>

%destructor {
    fprintf(stderr, "destroy create index param list\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <with_index_param_list_t>

/* %destructor {
    fprintf(stderr, "destroy if exists info\n");
    if (($$) != nullptr) {
        delete ($$);
    }
} <if_exists_info_t> */

%destructor {
    fprintf(stderr, "destroy if not exists info\n");
    if (($$) != nullptr) {
        delete ($$);
    }
} <if_not_exists_info_t>

%destructor {
    fprintf(stderr, "destroy table element array\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <table_element_array_t>

%destructor {
    fprintf(stderr, "destroy statement array\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <stmt_array>

%destructor {
    fprintf(stderr, "destroy expression array\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <expr_array_t>

%destructor {
    fprintf(stderr, "destroy expression array list\n");
    if (($$) != nullptr) {
        for (auto arr_ptr : *($$)) {
            for (auto ptr : *arr_ptr) {
                delete ptr;
            }
            delete (arr_ptr);
        }
        delete ($$);
    }
} <expr_array_list_t>

%destructor {
    fprintf(stderr, "destroy order by expr list\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <order_by_expr_list_t>

%destructor {
    fprintf(stderr, "destroy update expr\n");
    if($$ != nullptr) {
        delete $$;
    }
} <update_expr_t>

%destructor {
    fprintf(stderr, "destroy update expr array\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <update_expr_array_t>

%destructor {
    fprintf(stderr, "destroy with expr list\n");
    if (($$) != nullptr) {
        for (auto ptr : *($$)) {
            delete ptr;
        }
        delete ($$);
    }
} <with_expr_list_t>

%destructor {
    fprintf(stderr, "destroy table table_name\n");
    if (($$) != nullptr) {
        free($$->schema_name_ptr_);
        free($$->table_name_ptr_);
        delete ($$);
    }
} <table_name_t>

%destructor {
    fprintf(stderr, "destroy constraints\n");
    if (($$) != nullptr) {
        delete ($$);
    }
} <column_constraints_t>

%destructor {
    free($$);
} <str_value>

%destructor {
    fprintf(stderr, "destroy identifier array\n");
    delete ($$);
} <identifier_array_t>

%destructor {
    delete ($$);
} <expr_t>

%destructor {
    delete ($$);
} <const_expr_t>

%destructor {
    fprintf(stderr, "destroy table alias\n");
    delete ($$);
} <table_alias_t>

%destructor {
    fprintf(stderr, "destroy table reference\n");
    delete ($$);
} <table_reference_t>

%destructor {
    fprintf(stderr, "destroy order by expr\n");
    delete $$->expr_;
    delete $$;
} <order_by_expr_t>

%destructor {
    fprintf(stderr, "destroy with expr\n");
    delete $$->select_;
    delete $$;
} <with_expr_t>

%destructor {
    if($$ != nullptr) {
        delete $$;
    }
} <select_stmt>

%destructor {
    fprintf(stderr, "destroy case check array\n");
    if($$ != nullptr) {
        for(auto ptr: *($$)) {
            delete ptr;
        }
    }
} <case_check_array_t>

%destructor {
    delete ($$);
} <int_sparse_ele_t>

%destructor {
    delete ($$);
} <float_sparse_ele_t>

%token <str_value>              IDENTIFIER STRING
%token <double_value>           DOUBLE_VALUE
%token <long_value>             LONG_VALUE

/* SQL keywords */

%token CREATE SELECT INSERT DROP UPDATE DELETE COPY SET EXPLAIN SHOW ALTER EXECUTE PREPARE UNION ALL INTERSECT COMPACT
%token EXCEPT FLUSH USE OPTIMIZE PROPERTIES
%token DATABASE TABLE COLLECTION TABLES INTO VALUES AST PIPELINE RAW LOGICAL PHYSICAL FRAGMENT VIEW INDEX ANALYZE VIEWS DATABASES SEGMENT SEGMENTS BLOCK BLOCKS COLUMN COLUMNS INDEXES CHUNK
%token GROUP BY HAVING AS NATURAL JOIN LEFT RIGHT OUTER FULL ON INNER CROSS DISTINCT WHERE ORDER LIMIT OFFSET ASC DESC
%token IF NOT EXISTS IN FROM TO WITH DELIMITER FORMAT HEADER CAST END CASE ELSE THEN WHEN
%token BOOLEAN INTEGER INT TINYINT SMALLINT BIGINT HUGEINT VARCHAR FLOAT DOUBLE REAL DECIMAL DATE TIME DATETIME
%token TIMESTAMP UUID POINT LINE LSEG BOX PATH POLYGON CIRCLE BLOB BITMAP EMBEDDING VECTOR BIT TEXT TENSOR SPARSE TENSORARRAY
%token PRIMARY KEY UNIQUE NULLABLE IS DEFAULT
%token TRUE FALSE INTERVAL SECOND SECONDS MINUTE MINUTES HOUR HOURS DAY DAYS MONTH MONTHS YEAR YEARS
%token EQUAL NOT_EQ LESS_EQ GREATER_EQ BETWEEN AND OR EXTRACT LIKE
%token DATA LOG BUFFER TRANSACTIONS TRANSACTION
%token USING SESSION GLOBAL OFF EXPORT PROFILE CONFIGS CONFIG PROFILES VARIABLES VARIABLE
%token SEARCH MATCH MAXSIM QUERY QUERIES FUSION

%token NUMBER

/* nonterminal symbol */

%type <base_stmt>         statement explainable_statement
%type <create_stmt>       create_statement
%type <drop_stmt>         drop_statement
%type <copy_stmt>         copy_statement
%type <show_stmt>         show_statement
%type <select_stmt>       select_clause_without_modifier select_without_paren select_with_paren select_statement
%type <select_stmt>       select_clause_without_modifier_paren select_clause_with_modifier
%type <delete_stmt>       delete_statement
%type <update_stmt>       update_statement
%type <insert_stmt>       insert_statement
%type <explain_stmt>      explain_statement
%type <flush_stmt>        flush_statement
%type <optimize_stmt>     optimize_statement
%type <command_stmt>      command_statement
%type <compact_stmt>      compact_statement

%type <stmt_array>        statement_list

%type <table_element_t>         table_element
%type <table_column_t>          table_column
%type <column_type_t>           column_type
%type <identifier_array_t>      identifier_array optional_identifier_array
%type <table_constraint_t>      table_constraint
%type <column_constraint_t>     column_constraint
%type <column_constraints_t>    column_constraints

%type <table_reference_t>       table_reference table_reference_unit table_reference_name from_clause join_clause
%type <table_alias_t>           table_alias
%type <join_type_t>             join_type
%type <order_by_type_t>         order_by_type
%type <order_by_expr_t>         order_by_expr
%type <order_by_expr_list_t>    order_by_expr_list order_by_clause
%type <with_expr_t>             with_expr
%type <with_expr_list_t>        with_expr_list with_clause
%type <set_operator_t>          set_operator
%type <explain_type_t>          explain_type

%type <expr_t>                  expr expr_alias column_expr function_expr subquery_expr match_vector_expr match_tensor_expr match_sparse_expr sub_search
%type <expr_t>                  having_clause where_clause limit_expr offset_expr operand in_expr between_expr
%type <expr_t>                  conjunction_expr cast_expr case_expr
%type <expr_t>                  match_text_expr query_expr fusion_expr search_clause
%type <const_expr_t>            constant_expr interval_expr default_expr
%type <const_expr_t>            array_expr long_array_expr unclosed_long_array_expr double_array_expr unclosed_double_array_expr
%type <const_expr_t>            common_array_expr subarray_array_expr unclosed_subarray_array_expr
%type <const_expr_t>            sparse_array_expr long_sparse_array_expr unclosed_long_sparse_array_expr double_sparse_array_expr unclosed_double_sparse_array_expr
%type <const_expr_t>            empty_array_expr common_sparse_array_expr
%type <int_sparse_ele_t>        int_sparse_ele
%type <float_sparse_ele_t>      float_sparse_ele
%type <expr_array_t>            expr_array group_by_clause sub_search_array
%type <expr_array_list_t>       expr_array_list
%type <update_expr_t>           update_expr;
%type <update_expr_array_t>     update_expr_array;
%type <case_check_array_t>      case_check_array;

%type <table_element_array_t>   table_element_array

%type <table_name_t>      table_name
%type <copy_option_array> copy_option_list
%type <copy_option_t>     copy_option

%type <str_value>         file_path extra_match_tensor_option

%type <bool_value>        if_not_exists if_exists distinct

%type <index_param_t> index_param
%type <index_param_list_t> index_param_list
%type <with_index_param_list_t> with_index_param_list optional_table_properties_list

%type <index_info_list_t> index_info_list

/* %type <if_exists_info_t> if_exists_info */
%type <if_not_exists_info_t> if_not_exists_info 

/*
 * Operator precedence, low to high
 */

%left       OR
%left       AND
%left       BETWEEN CASE WHEN THEN ELSE
%right      NOT

%nonassoc   '=' EQUAL NOT_EQ LIKE
%nonassoc   '<' '>' LESS_EQ GREATER_EQ

%nonassoc   IS
%left       '+' '-'
%left       '*' '/' '%'

%left       '[' ']'
%left       '(' ')'
%left       '.'
%left       JOIN

%%

input_pattern : statement_list semicolon {
    result->statements_ptr_ = $1;
};

statement_list : statement {
    $1->stmt_length_ = yylloc.string_length;
    yylloc.string_length = 0;
    $$ = new std::vector<infinity::BaseStatement*>();
    $$->push_back($1);
}
| statement_list ';' statement {
    $3->stmt_length_ = yylloc.string_length;
    yylloc.string_length = 0;
    $1->push_back($3);
    $$ = $1;
};

statement : create_statement { $$ = $1; }
| drop_statement { $$ = $1; }
| copy_statement { $$ = $1; }
| show_statement { $$ = $1; }
| select_statement { $$ = $1; }
| delete_statement { $$ = $1; }
| update_statement { $$ = $1; }
| insert_statement { $$ = $1; }
| explain_statement { $$ = $1; }
| flush_statement { $$ = $1; }
| optimize_statement { $$ = $1; }
| command_statement { $$ = $1; }
| compact_statement { $$ = $1; }

explainable_statement : create_statement { $$ = $1; }
| drop_statement { $$ = $1; }
| copy_statement { $$ = $1; }
| show_statement { $$ = $1; }
| select_statement { $$ = $1; }
| delete_statement { $$ = $1; }
| update_statement { $$ = $1; }
| insert_statement { $$ = $1; }
| flush_statement { $$ = $1; }
| optimize_statement { $$ = $1; }
| command_statement { $$ = $1; }
| compact_statement { $$ = $1; }

/*
 * CREATE STATEMENT
 */

/* CREATE DATABASE schema_name; */
create_statement : CREATE DATABASE if_not_exists IDENTIFIER {
    $$ = new infinity::CreateStatement();
    std::shared_ptr<infinity::CreateSchemaInfo> create_schema_info = std::make_shared<infinity::CreateSchemaInfo>();

    ParserHelper::ToLower($4);
    create_schema_info->schema_name_ = $4;
    free($4);
    if(create_schema_info->schema_name_.empty()) {
        yyerror(&yyloc, scanner, result, "Empty database name is given.");
        YYERROR;
    }

    $$->create_info_ = create_schema_info;
    $$->create_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
}

/* CREATE COLLECTION collection_name; */
| CREATE COLLECTION if_not_exists table_name {
    $$ = new infinity::CreateStatement();
    std::shared_ptr<infinity::CreateCollectionInfo> create_collection_info = std::make_shared<infinity::CreateCollectionInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        create_collection_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    create_collection_info->collection_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    $$->create_info_ = create_collection_info;
    $$->create_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    delete $4;
}

/* CREATE TABLE table_name ( column list ); */
/* CREATE TABLE table_name ( column list ) PROPERTIES ("p1"="111", "p2"="xxx", ...); */
| CREATE TABLE if_not_exists table_name '(' table_element_array ')' optional_table_properties_list {
    $$ = new infinity::CreateStatement();
    std::shared_ptr<infinity::CreateTableInfo> create_table_info = std::make_shared<infinity::CreateTableInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        create_table_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    create_table_info->table_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    delete $4;

    for (infinity::TableElement*& element : *$6) {
        if(element->type_ == infinity::TableElementType::kColumn) {
            create_table_info->column_defs_.emplace_back((infinity::ColumnDef*)element);
        } else {
            create_table_info->constraints_.emplace_back((infinity::TableConstraint*)element);
        }
    }
    delete $6;

    if ($8 != nullptr) {
        create_table_info->properties_ = std::move(*$8);
        delete $8;
    }

    $$->create_info_ = create_table_info;
    $$->create_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
}
/* CREATE TABLE table_name AS SELECT .... ; */
| CREATE TABLE if_not_exists table_name AS select_statement {
    $$ = new infinity::CreateStatement();
    std::shared_ptr<infinity::CreateTableInfo> create_table_info = std::make_shared<infinity::CreateTableInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        create_table_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    create_table_info->table_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    delete $4;

    create_table_info->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    create_table_info->select_ = $6;
    $$->create_info_ = create_table_info;
}
/* CREATE VIEW table_name AS SELECT .... ; */
| CREATE VIEW if_not_exists table_name optional_identifier_array AS select_statement {
    $$ = new infinity::CreateStatement();
    std::shared_ptr<infinity::CreateViewInfo> create_view_info = std::make_shared<infinity::CreateViewInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        create_view_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    create_view_info->view_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    delete $4;

    create_view_info->view_columns_ = $5;
    create_view_info->select_ = $7;
    create_view_info->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    $$->create_info_ = create_view_info;
}
// TODO shenyushi 4: should support default index name if the name does not exist
/* CREATE INDEX [[IF NOT EXISTS] index_name] ON table_name (column1[, ...column2]) USING method [WITH (param[, ...param])]; */
| CREATE INDEX if_not_exists_info ON table_name index_info_list {
    std::shared_ptr<infinity::CreateIndexInfo> create_index_info = std::make_shared<infinity::CreateIndexInfo>();
    if($5->schema_name_ptr_ != nullptr) {
        create_index_info->schema_name_ = $5->schema_name_ptr_;
        free($5->schema_name_ptr_);
    }
    create_index_info->table_name_ = $5->table_name_ptr_;
    free($5->table_name_ptr_);
    delete $5;

    create_index_info->index_name_ = $3->info_;
    if ($3->exists_) {
        create_index_info->conflict_type_ = $3->if_not_exists_ ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    } else {
        create_index_info->conflict_type_ = infinity::ConflictType::kIgnore;
    }
    delete $3;

    create_index_info->index_info_list_ = $6;

    if(create_index_info->index_name_.empty()) {
        yyerror(&yyloc, scanner, result, "No index name");
        YYERROR;
    }

    $$ = new infinity::CreateStatement();
    $$->create_info_ = create_index_info;
};

table_element_array : table_element {
    $$ = new std::vector<infinity::TableElement*>();
    $$->push_back($1);
}
| table_element_array ',' table_element {
    $1->push_back($3);
    $$ = $1;
};


table_element : table_column {
    $$ = $1;
}
| table_constraint {
    $$ = $1;
};


table_column :
//   1          2              3                  4
IDENTIFIER column_type with_index_param_list default_expr {
    std::shared_ptr<infinity::TypeInfo> type_info_ptr{nullptr};
    std::vector<std::unique_ptr<infinity::InitParameter>> index_param_list = infinity::InitParameter::MakeInitParameterList($3);
    switch($2.logical_type_) {
        case infinity::LogicalType::kDecimal: {
            type_info_ptr = infinity::DecimalInfo::Make($2.precision, $2.scale);
            if(type_info_ptr == nullptr) {
                yyerror(&yyloc, scanner, result, "Fail to create decimal info.");
                free($1);
                YYERROR;
            }
            break;
        }
//        case infinity::LogicalType::kBitmap: {
//            type_info_ptr = infinity::BitmapInfo::Make($2.width);
//            break;
//        }
        case infinity::LogicalType::kTensor:
        case infinity::LogicalType::kTensorArray:
        case infinity::LogicalType::kEmbedding: {
            type_info_ptr = infinity::EmbeddingInfo::Make($2.embedding_type_, $2.width);
            break;
        }
        case infinity::LogicalType::kSparse: {
            auto store_type = infinity::SparseInfo::ParseStoreType(index_param_list);
            type_info_ptr = infinity::SparseInfo::Make($2.embedding_type_, $2.width, store_type);
            if (type_info_ptr == nullptr) {
                yyerror(&yyloc, scanner, result, "Fail to create sparse info.");
                free($1);
                YYERROR;
            }
            break;
        }
        default: {
            break;
        }
    }

    std::shared_ptr<infinity::ParsedExpr> default_expr($4);
    $$ = new infinity::ColumnDef($2.logical_type_, type_info_ptr, std::move(default_expr));

    ParserHelper::ToLower($1);
    $$->name_ = $1;
    free($1);
    /*
    if (!$$->trySetNullableExplicit()) {
        yyerror(&yyloc, result, scanner, ("Conflicting nullability constraints for " + std::string{$1}).c_str());
    }
    */
};
| IDENTIFIER column_type column_constraints default_expr {
    std::shared_ptr<infinity::TypeInfo> type_info_ptr{nullptr};
    switch($2.logical_type_) {
        case infinity::LogicalType::kDecimal: {
            type_info_ptr = infinity::DecimalInfo::Make($2.precision, $2.scale);
            break;
        }
//        case infinity::LogicalType::kBitmap: {
//            type_info_ptr = infinity::BitmapInfo::Make($2.width);
//            break;
//        }
        case infinity::LogicalType::kEmbedding: {
            type_info_ptr = infinity::EmbeddingInfo::Make($2.embedding_type_, $2.width);
            break;
        }
        default: {
            break;
        }
    }

    std::shared_ptr<infinity::ParsedExpr> default_expr($4);
    $$ = new infinity::ColumnDef($2.logical_type_, type_info_ptr, default_expr);

    ParserHelper::ToLower($1);
    $$->name_ = $1;
    $$->constraints_ = *$3;
    delete $3;
    free($1);
    /*
    if (!$$->trySetNullableExplicit()) {
        yyerror(&yyloc, result, scanner, ("Conflicting nullability constraints for " + std::string{$1}).c_str());
    }
    */
};

column_type :
BOOLEAN { $$ = infinity::ColumnType{infinity::LogicalType::kBoolean, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| TINYINT { $$ = infinity::ColumnType{infinity::LogicalType::kTinyInt, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| SMALLINT { $$ = infinity::ColumnType{infinity::LogicalType::kSmallInt, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| INTEGER { $$ = infinity::ColumnType{infinity::LogicalType::kInteger, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| INT { $$ = infinity::ColumnType{infinity::LogicalType::kInteger, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| BIGINT { $$ = infinity::ColumnType{infinity::LogicalType::kBigInt, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| HUGEINT { $$ = infinity::ColumnType{infinity::LogicalType::kHugeInt, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| FLOAT { $$ = infinity::ColumnType{infinity::LogicalType::kFloat, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| REAL  { $$ = infinity::ColumnType{infinity::LogicalType::kFloat, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| DOUBLE { $$ = infinity::ColumnType{infinity::LogicalType::kDouble, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| DATE { $$ = infinity::ColumnType{infinity::LogicalType::kDate, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| TIME { $$ = infinity::ColumnType{infinity::LogicalType::kTime, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| DATETIME { $$ = infinity::ColumnType{infinity::LogicalType::kDateTime, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| TIMESTAMP { $$ = infinity::ColumnType{infinity::LogicalType::kTimestamp, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| UUID { $$ = infinity::ColumnType{infinity::LogicalType::kUuid, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| POINT { $$ = infinity::ColumnType{infinity::LogicalType::kPoint, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| LINE { $$ = infinity::ColumnType{infinity::LogicalType::kLine, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| LSEG { $$ = infinity::ColumnType{infinity::LogicalType::kLineSeg, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| BOX { $$ = infinity::ColumnType{infinity::LogicalType::kBox, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
// | PATH { $$ = infinity::ColumnType{infinity::LogicalType::kPath, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
// | POLYGON { $$ = infinity::ColumnType{infinity::LogicalType::kPolygon, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| CIRCLE { $$ = infinity::ColumnType{infinity::LogicalType::kCircle, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
// Variable types
| VARCHAR { $$ = infinity::ColumnType{infinity::LogicalType::kVarchar, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| DECIMAL '(' LONG_VALUE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kDecimal, 0, $3, $5, infinity::EmbeddingDataType::kElemInvalid}; }
| DECIMAL '(' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kDecimal, 0, $3, 0, infinity::EmbeddingDataType::kElemInvalid}; }
| DECIMAL { $$ = infinity::ColumnType{infinity::LogicalType::kDecimal, 0, 0, 0, infinity::EmbeddingDataType::kElemInvalid}; }
// | BLOB '(' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kBlob, $3}; }
// | BITMAP '(' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kBitmap, $3}; }
| EMBEDDING '(' BIT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemBit}; }
| EMBEDDING '(' TINYINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt8}; }
| EMBEDDING '(' SMALLINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt16}; }
| EMBEDDING '(' INTEGER ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt32}; }
| EMBEDDING '(' INT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt32}; }
| EMBEDDING '(' BIGINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt64}; }
| EMBEDDING '(' FLOAT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemFloat}; }
| EMBEDDING '(' DOUBLE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemDouble}; }
| TENSOR '(' BIT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemBit}; }
| TENSOR '(' TINYINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemInt8}; }
| TENSOR '(' SMALLINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemInt16}; }
| TENSOR '(' INTEGER ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemInt32}; }
| TENSOR '(' INT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemInt32}; }
| TENSOR '(' BIGINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemInt64}; }
| TENSOR '(' FLOAT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemFloat}; }
| TENSOR '(' DOUBLE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensor, $5, 0, 0, infinity::kElemDouble}; }
| TENSORARRAY '(' BIT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemBit}; }
| TENSORARRAY '(' TINYINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemInt8}; }
| TENSORARRAY '(' SMALLINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemInt16}; }
| TENSORARRAY '(' INTEGER ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemInt32}; }
| TENSORARRAY '(' INT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemInt32}; }
| TENSORARRAY '(' BIGINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemInt64}; }
| TENSORARRAY '(' FLOAT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemFloat}; }
| TENSORARRAY '(' DOUBLE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kTensorArray, $5, 0, 0, infinity::kElemDouble}; }
| VECTOR '(' BIT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemBit}; }
| VECTOR '(' TINYINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt8}; }
| VECTOR '(' SMALLINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt16}; }
| VECTOR '(' INTEGER ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt32}; }
| VECTOR '(' INT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt32}; }
| VECTOR '(' BIGINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemInt64}; }
| VECTOR '(' FLOAT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemFloat}; }
| VECTOR '(' DOUBLE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kEmbedding, $5, 0, 0, infinity::kElemDouble}; }
| SPARSE '(' BIT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemBit}; }
| SPARSE '(' TINYINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemInt8}; }
| SPARSE '(' SMALLINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemInt16}; }
| SPARSE '(' INTEGER ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemInt32}; }
| SPARSE '(' INT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemInt32}; }
| SPARSE '(' BIGINT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemInt64}; }
| SPARSE '(' FLOAT ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemFloat}; }
| SPARSE '(' DOUBLE ',' LONG_VALUE ')' { $$ = infinity::ColumnType{infinity::LogicalType::kSparse, $5, 0, 0, infinity::kElemDouble}; }
/*
| DECIMAL opt_decimal_specification {
  $$ = infinity::ColumnType{DataType::DECIMAL, 0, $2->first, $2->second};
  delete $2;
}
| TEXT { $$ = infinity::ColumnType{DataType::TEXT}; }
| TIME opt_time_precision { $$ = infinity::ColumnType{DataType::TIME, 0, $2}; }
| TIMESTAMP { $$ = infinity::ColumnType{DataType::DATETIME}; }
| VARCHAR '(' INTVAL ')' { $$ = infinity::ColumnType{DataType::VARCHAR, $3}; }

opt_time_precision : '(' INTVAL ')' { $$ = $2; }
| { $$ = 0; };

opt_decimal_specification : '(' INTVAL ',' INTVAL ')' { $$ = new std::pair<int64_t, int64_t>{$2, $4}; }
| '(' INTVAL ')' { $$ = new std::pair<int64_t, int64_t>{$2, 0}; }
|  { $$ = new std::pair<int64_t, int64_t>{0, 0}; };
*/

column_constraints : column_constraint {
    $$ = new std::set<infinity::ConstraintType>();
    $$->insert($1);
}
| column_constraints column_constraint {
    if($1->contains($2)) {
        yyerror(&yyloc, scanner, result, "Duplicate column constraint.");
        delete $1;
        YYERROR;
    }
    $1->insert($2);
    $$ = $1;
}

column_constraint : PRIMARY KEY {
    $$ = infinity::ConstraintType::kPrimaryKey;
}
| UNIQUE {
    $$ = infinity::ConstraintType::kUnique;
}
| NULLABLE {
    $$ = infinity::ConstraintType::kNull;
}
| NOT NULLABLE {
    $$ = infinity::ConstraintType::kNotNull;
};

default_expr : DEFAULT constant_expr {
    $$ = $2;
}
| /* empty default value */ {
    $$ = nullptr;
};


table_constraint : PRIMARY KEY '(' identifier_array ')' {
    $$ = new infinity::TableConstraint();
    $$->names_ptr_ = $4;
    $$->constraint_ = infinity::ConstraintType::kPrimaryKey;
}
| UNIQUE '(' identifier_array ')' {
    $$ = new infinity::TableConstraint();
    $$->names_ptr_ = $3;
    $$->constraint_ = infinity::ConstraintType::kUnique;
};


identifier_array : IDENTIFIER {
    $$ = new std::vector<std::string>();
    ParserHelper::ToLower($1);
    $$->emplace_back($1);
    free($1);
}
| identifier_array ',' IDENTIFIER {
    ParserHelper::ToLower($3);
    $1->emplace_back($3);
    free($3);
    $$ = $1;
};

/*
 * DELETE STATEMENT
 */
delete_statement : DELETE FROM table_name where_clause {
    $$ = new infinity::DeleteStatement();

    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
    $$->where_expr_ = $4;
};

/*
 * INSERT STATEMENT
 */
insert_statement: INSERT INTO table_name optional_identifier_array VALUES expr_array_list {
    bool is_error{false};
    for (auto expr_array : *$6) {
        for (auto expr : *expr_array) {
            if(expr->type_ != infinity::ParsedExprType::kConstant) {
                yyerror(&yyloc, scanner, result, ("Value list has non-constant expression: " + expr->ToString()).c_str());
                is_error = true;
            }
        }
    }
    if(is_error) {
        for (auto expr_array : *$6) {
            for (auto expr : *expr_array) {
                delete expr;
            }
            delete (expr_array);
        }
        delete $6;
        delete $3;
        delete $4;
        YYERROR;
    }

    $$ = new infinity::InsertStatement();
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
    $$->columns_ = $4;
    $$->values_ = $6;
}
| INSERT INTO table_name optional_identifier_array select_without_paren {
    $$ = new infinity::InsertStatement();
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
    $$->columns_ = $4;
    $$->select_ = $5;
}

optional_identifier_array: '(' identifier_array ')' {
    $$ = $2;
}
| {
    $$ = nullptr;
}

/*
 * EXPLAIN STATEMENT
 */
explain_statement : EXPLAIN explain_type explainable_statement {
    $$ = new infinity::ExplainStatement();
    $$->type_ = $2;
    $$->statement_ = $3;
}

explain_type: ANALYZE {
    $$ = infinity::ExplainType::kAnalyze;
}
| AST {
    $$ = infinity::ExplainType::kAst;
}
| RAW {
    $$ = infinity::ExplainType::kUnOpt;
}
| LOGICAL {
    $$ = infinity::ExplainType::kOpt;
}
| PHYSICAL {
    $$ = infinity::ExplainType::kPhysical;
}
| PIPELINE {
    $$ = infinity::ExplainType::kPipeline;
}
| FRAGMENT {
    $$ = infinity::ExplainType::kFragment;
}
| {
    $$ = infinity::ExplainType::kPhysical;
}

/*
 * UPDATE STATEMENT
 */
update_statement: UPDATE table_name SET update_expr_array where_clause {
    $$ = new infinity::UpdateStatement();
    if($2->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $2->schema_name_ptr_;
        free($2->schema_name_ptr_);
    }
    $$->table_name_ = $2->table_name_ptr_;
    free($2->table_name_ptr_);
    delete $2;
    $$->where_expr_ = $5;
    $$->update_expr_array_ = $4;
}

update_expr_array: update_expr {
    $$ = new std::vector<infinity::UpdateExpr*>();
    $$->emplace_back($1);
}
| update_expr_array ',' update_expr {
    $1->emplace_back($3);
    $$ = $1;
}

update_expr : IDENTIFIER '=' expr {
    $$ = new infinity::UpdateExpr();
    ParserHelper::ToLower($1);
    $$->column_name = $1;
    free($1);
    $$->value = $3;
};

/*
 * DROP STATEMENT
 */

/* DROP DATABASE schema_name; */
drop_statement: DROP DATABASE if_exists IDENTIFIER {
    $$ = new infinity::DropStatement();
    std::shared_ptr<infinity::DropSchemaInfo> drop_schema_info = std::make_shared<infinity::DropSchemaInfo>();

    ParserHelper::ToLower($4);
    drop_schema_info->schema_name_ = $4;
    free($4);

    $$->drop_info_ = drop_schema_info;
    $$->drop_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
};

/* DROP COLLECTION collection_name; */
| DROP COLLECTION if_exists table_name {
    $$ = new infinity::DropStatement();
    std::shared_ptr<infinity::DropCollectionInfo> drop_collection_info = std::make_unique<infinity::DropCollectionInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        drop_collection_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    drop_collection_info->collection_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    $$->drop_info_ = drop_collection_info;
    $$->drop_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    delete $4;
}

/* DROP TABLE table_name; */
| DROP TABLE if_exists table_name {
    $$ = new infinity::DropStatement();
    std::shared_ptr<infinity::DropTableInfo> drop_table_info = std::make_unique<infinity::DropTableInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        drop_table_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    drop_table_info->table_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    $$->drop_info_ = drop_table_info;
    $$->drop_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    delete $4;
}

/* DROP VIEW view_name; */
| DROP VIEW if_exists table_name {
    $$ = new infinity::DropStatement();
    std::shared_ptr<infinity::DropViewInfo> drop_view_info = std::make_unique<infinity::DropViewInfo>();
    if($4->schema_name_ptr_ != nullptr) {
        drop_view_info->schema_name_ = $4->schema_name_ptr_;
        free($4->schema_name_ptr_);
    }
    drop_view_info->view_name_ = $4->table_name_ptr_;
    free($4->table_name_ptr_);
    $$->drop_info_ = drop_view_info;
    $$->drop_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;
    delete $4;
}

/* DROP INDEX index_name ON table_name; */
| DROP INDEX if_exists IDENTIFIER ON table_name {
    $$ = new infinity::DropStatement();
    std::shared_ptr<infinity::DropIndexInfo> drop_index_info = std::make_shared<infinity::DropIndexInfo>();

    $$->drop_info_ = drop_index_info;
    $$->drop_info_->conflict_type_ = $3 ? infinity::ConflictType::kIgnore : infinity::ConflictType::kError;

    drop_index_info->index_name_ = $4;
    free($4);

    if($6->schema_name_ptr_ != nullptr) {
        drop_index_info->schema_name_ = $6->schema_name_ptr_;
        free($6->schema_name_ptr_);
    }
    drop_index_info->table_name_ = $6->table_name_ptr_;
    free($6->table_name_ptr_);
    delete $6;
};

/*
 * COPY STATEMENT
 */
// COPY database.table TO file_path WITH (FORMAT csv, DELIMITER ',', HEADER)
copy_statement: COPY table_name TO file_path WITH '(' copy_option_list ')' {
    $$ = new infinity::CopyStatement();

    // Copy To
    $$->copy_from_ = false;

    // table_name
    if($2->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $2->schema_name_ptr_;
        free($2->schema_name_ptr_);
    }
    $$->table_name_ = $2->table_name_ptr_;
    free($2->table_name_ptr_);
    delete $2;

    // file path
    $$->file_path_ = $4;
    free($4);

    // copy options
    size_t option_count = (*$7).size();
    for(size_t idx = 0; idx < option_count; ++ idx) {
        infinity::CopyOption* option_ptr = (*$7)[idx];
        switch(option_ptr->option_type_) {
            case infinity::CopyOptionType::kFormat: {
                $$->copy_file_type_ = option_ptr->file_type_;
                break;
            }
            case infinity::CopyOptionType::kDelimiter: {
                $$->delimiter_ = option_ptr->delimiter_;
                break;
            }
            case infinity::CopyOptionType::kHeader: {
                $$->header_ = option_ptr->header_;
                break;
            }
        }
        delete option_ptr;
    }
    delete $7;
}
| COPY table_name '(' expr_array ')' TO file_path WITH '(' copy_option_list ')' {
    $$ = new infinity::CopyStatement();

    // Copy To
    $$->copy_from_ = false;

    // table_name
    if($2->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $2->schema_name_ptr_;
        free($2->schema_name_ptr_);
    }
    $$->table_name_ = $2->table_name_ptr_;
    free($2->table_name_ptr_);
    delete $2;

    $$->expr_array_ = $4;

    // file path
    $$->file_path_ = $7;
    free($7);

    // copy options
    size_t option_count = (*$10).size();
    for(size_t idx = 0; idx < option_count; ++ idx) {
        infinity::CopyOption* option_ptr = (*$10)[idx];
        switch(option_ptr->option_type_) {
            case infinity::CopyOptionType::kFormat: {
                $$->copy_file_type_ = option_ptr->file_type_;
                break;
            }
            case infinity::CopyOptionType::kDelimiter: {
                $$->delimiter_ = option_ptr->delimiter_;
                break;
            }
            case infinity::CopyOptionType::kHeader: {
                $$->header_ = option_ptr->header_;
                break;
            }
        }
        delete option_ptr;
    }
    delete $10;
}
| COPY table_name FROM file_path WITH '(' copy_option_list ')' {
    $$ = new infinity::CopyStatement();

    // Copy From
    $$->copy_from_ = true;

    // table_name
    if($2->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $2->schema_name_ptr_;
        free($2->schema_name_ptr_);
    }
    $$->table_name_ = $2->table_name_ptr_;
    free($2->table_name_ptr_);
    delete $2;

    // file path
    $$->file_path_ = $4;
    free($4);

    // copy options
    size_t option_count = (*$7).size();
    for(size_t idx = 0; idx < option_count; ++ idx) {
        infinity::CopyOption* option_ptr = (*$7)[idx];
        switch(option_ptr->option_type_) {
            case infinity::CopyOptionType::kFormat: {
                $$->copy_file_type_ = option_ptr->file_type_;
                break;
            }
            case infinity::CopyOptionType::kDelimiter: {
                $$->delimiter_ = option_ptr->delimiter_;
                break;
            }
            case infinity::CopyOptionType::kHeader: {
                $$->header_ = option_ptr->header_;
                break;
            }
        }
        delete option_ptr;
    }
    delete $7;
};

/*
 * SELECT STATEMENT
 */
select_statement : select_without_paren {
    $$ = $1;
}
| select_with_paren {
    $$ = $1;
}
| select_statement set_operator select_clause_without_modifier_paren {
    infinity::SelectStatement* node = $1;
    while(node->nested_select_ != nullptr) {
        node = node->nested_select_;
    }
    node->set_op_ = $2;
    node->nested_select_ = $3;
    $$ = $1;
}
| select_statement set_operator select_clause_without_modifier {
    infinity::SelectStatement* node = $1;
    while(node->nested_select_ != nullptr) {
        node = node->nested_select_;
    }
    node->set_op_ = $2;
    node->nested_select_ = $3;
    $$ = $1;
}

select_with_paren : '(' select_without_paren ')' {
    $$ = $2;
}
| '(' select_with_paren ')' {
    $$ = $2;
};

select_without_paren: with_clause select_clause_with_modifier {
    $2->with_exprs_ = $1;
    $$ = $2;
};

select_clause_with_modifier: select_clause_without_modifier order_by_clause limit_expr offset_expr {
    if($3 == nullptr and $4 != nullptr) {
        delete $1;
        delete $2;
        delete $4;
        yyerror(&yyloc, scanner, result, "Offset expression isn't valid without Limit expression");
        YYERROR;
    }
    if($1->search_expr_ != nullptr and ($2 != nullptr or $3 != nullptr or $4 != nullptr)) {
        delete $1;
        delete $2;
        delete $3;
        delete $4;
        yyerror(&yyloc, scanner, result, "Result modifier(ORDER BY, LIMIT, OFFSET) is conflict with SEARCH expression.");
        YYERROR;
    }
    $1->order_by_list = $2;
    $1->limit_expr_ = $3;
    $1->offset_expr_ = $4;
    $$ = $1;
}

select_clause_without_modifier_paren: '(' select_clause_without_modifier ')' {
  $$ = $2;
}
| '(' select_clause_without_modifier_paren ')' {
    $$ = $2;
};

select_clause_without_modifier:
SELECT distinct expr_array from_clause search_clause where_clause group_by_clause having_clause {
    $$ = new infinity::SelectStatement();
    $$->select_list_ = $3;
    $$->select_distinct_ = $2;
    $$->table_ref_ = $4;
    $$->search_expr_ = $5;
    $$->where_expr_ = $6;
    $$->group_by_list_ = $7;
    $$->having_expr_ = $8;

    if($$->group_by_list_ == nullptr && $$->having_expr_ != nullptr) {
        yyerror(&yyloc, scanner, result, "HAVING clause should follow after GROUP BY clause");
        YYERROR;
    }
};

order_by_clause : ORDER BY order_by_expr_list {
    $$ = $3;
}
| /* empty order by */ {
    $$ = nullptr;
};

order_by_expr_list: order_by_expr {
    $$ = new std::vector<infinity::OrderByExpr*>();
    $$->emplace_back($1);
}
| order_by_expr_list ',' order_by_expr {
    $1->emplace_back($3);
    $$ = $1;
}

order_by_expr : expr order_by_type {
    $$ = new infinity::OrderByExpr();
    $$->expr_ = $1;
    $$->type_ = $2;
};

order_by_type: ASC {
    $$ = infinity::kAsc;
}
| DESC {
    $$ = infinity::kDesc;
}
| {
    $$ = infinity::kAsc;
}

limit_expr: LIMIT expr {
    $$ = $2;
}
| /* empty limit expression */
{   $$ = nullptr; };

offset_expr: OFFSET expr {
    $$ = $2;
}
| /* empty offset expression */
{   $$ = nullptr; };

distinct : DISTINCT {
    $$ = true;
}
| {
    $$ = false;
}

from_clause: FROM table_reference {
    $$ = $2;
}
| /* no from clause */ {
    $$ = nullptr;
}

search_clause: SEARCH sub_search_array {
    infinity::SearchExpr* search_expr = new infinity::SearchExpr();
    search_expr->SetExprs($2);
    $$ = search_expr;
}
| /* no search clause */ {
    $$ = nullptr;
}

where_clause: WHERE expr {
    $$ = $2;
}
| /* no where clause */ {
    $$ = nullptr;
}

having_clause: HAVING expr {
    $$ = $2;
}
| /* no where clause */ {
    $$ = nullptr;
}

group_by_clause: GROUP BY expr_array {
    $$ = $3;
}
| {
    $$ = nullptr;
}

set_operator : UNION {
    $$ = infinity::SetOperatorType::kUnion;
}
| UNION ALL {
    $$ = infinity::SetOperatorType::kUnionAll;
}
| INTERSECT {
    $$ = infinity::SetOperatorType::kIntersect;
}
| EXCEPT {
    $$ = infinity::SetOperatorType::kExcept;
};

/*
 * TABLE REFERENCE
 */

table_reference : table_reference_unit {
    $$ = $1;
}
| table_reference ',' table_reference_unit {
    infinity::CrossProductReference* cross_product_ref = nullptr;
    if($1->type_ == infinity::TableRefType::kCrossProduct) {
        cross_product_ref = (infinity::CrossProductReference*)$1;
        cross_product_ref->tables_.emplace_back($3);
    } else {
        cross_product_ref = new infinity::CrossProductReference();
        cross_product_ref->tables_.emplace_back($1);
        cross_product_ref->tables_.emplace_back($3);
    }

    $$ = cross_product_ref;
};


table_reference_unit : table_reference_name | join_clause;

table_reference_name : table_name table_alias {
    infinity::TableReference* table_ref = new infinity::TableReference();
    if($1->schema_name_ptr_ != nullptr) {
        table_ref->db_name_ = $1->schema_name_ptr_;
        free($1->schema_name_ptr_);
    }
    table_ref->table_name_ = $1->table_name_ptr_;
    free($1->table_name_ptr_);
    delete $1;

    table_ref->alias_ = $2;
    $$ = table_ref;
}
/* FROM (select * from t1) AS t2 */
| '(' select_statement ')' table_alias {
    infinity::SubqueryReference* subquery_reference = new infinity::SubqueryReference();
    subquery_reference->select_statement_ = $2;
    subquery_reference->alias_ = $4;
    $$ = subquery_reference;
}


/* 'table_name' or 'schema_name.table_name' */
table_name : IDENTIFIER {
    $$ = new infinity::TableName();
    ParserHelper::ToLower($1);
    $$->table_name_ptr_ = $1;
}
| IDENTIFIER '.' IDENTIFIER {
    $$ = new infinity::TableName();
    ParserHelper::ToLower($1);
    ParserHelper::ToLower($3);
    $$->schema_name_ptr_ = $1;
    $$->table_name_ptr_ = $3;
};

/* AS 'table_alias' or AS 'table_alias(col1_alias, col2_alias ... )' */
table_alias : AS IDENTIFIER {
    $$ = new infinity::TableAlias();
    ParserHelper::ToLower($2);
    $$->alias_ = $2;
}
| IDENTIFIER {
    $$ = new infinity::TableAlias();
    ParserHelper::ToLower($1);
    $$->alias_ = $1;
}
| AS IDENTIFIER '(' identifier_array ')' {
    $$ = new infinity::TableAlias();
    ParserHelper::ToLower($2);
    $$->alias_ = $2;
    $$->column_alias_array_ = $4;
}
| {
    $$ = nullptr;
}

/*
 * WITH CLAUSE
 */
with_clause : WITH with_expr_list {
    $$ = $2;
}
| /* empty with clause */ {
    $$ = nullptr;
}

with_expr_list: with_expr {
    $$ = new std::vector<infinity::WithExpr*>();
    $$->emplace_back($1);
} | with_expr_list ',' with_expr {
    $1->emplace_back($3);
    $$ = $1;
}

with_expr: IDENTIFIER AS '(' select_clause_with_modifier ')' {
    $$ = new infinity::WithExpr();
    ParserHelper::ToLower($1);
    $$->alias_ = $1;
    free($1);
    $$->select_ = $4;
}

/*
 * JOIN CLAUSE
 */

join_clause: table_reference_unit NATURAL JOIN table_reference_name {
    infinity::JoinReference* join_reference = new infinity::JoinReference();
    join_reference->left_ = $1;
    join_reference->right_ = $4;
    join_reference->join_type_ = infinity::JoinType::kNatural;
    $$ = join_reference;
}
| table_reference_unit join_type JOIN table_reference_name ON expr {
    infinity::JoinReference* join_reference = new infinity::JoinReference();
    join_reference->left_ = $1;
    join_reference->right_ = $4;
    join_reference->join_type_ = $2;
    join_reference->condition_ = $6;
    $$ = join_reference;
};
/* Using column name to JOIN
| table_reference_unit join_type JOIN table_reference_name USING '(' column_name ')' {
}
*/


join_type : INNER {
    $$ = infinity::JoinType::kInner;
}
| LEFT {
    $$ = infinity::JoinType::kLeft;
}
| RIGHT {
    $$ = infinity::JoinType::kRight;
}
| OUTER {
    $$ = infinity::JoinType::kFull;
}
| FULL {
    $$ = infinity::JoinType::kFull;
}
| CROSS {
    $$ = infinity::JoinType::kCross;
}
| /* default */ {
};

/*
 * SHOW STATEMENT
 */
show_statement: SHOW DATABASES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kDatabases;
}
| SHOW TABLES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kTables;
}
| SHOW VIEWS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kViews;
}
| SHOW CONFIGS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kConfigs;
}
| SHOW CONFIG IDENTIFIER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kConfig;
    ParserHelper::ToLower($3);
    $$->var_name_ = std::string($3);
    free($3);
}
| SHOW PROFILES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kProfiles;
}
| SHOW BUFFER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kBuffer;
}
| SHOW QUERIES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kQueries;
}
| SHOW QUERY SESSION LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kQuery;
    $$->session_id_ = $4;
}
| SHOW TRANSACTIONS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kTransactions;
}
| SHOW TRANSACTION LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kTransaction;
    $$->txn_id_ = $3;
}
| SHOW SESSION VARIABLES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kSessionVariables;
}
| SHOW GLOBAL VARIABLES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kGlobalVariables;
}
| SHOW SESSION VARIABLE IDENTIFIER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kSessionVariable;
    $$->var_name_ = std::string($4);
    free($4);
}
| SHOW GLOBAL VARIABLE IDENTIFIER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kGlobalVariable;
    $$->var_name_ = std::string($4);
    free($4);
}
| SHOW DATABASE IDENTIFIER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kDatabase;
    $$->schema_name_ = $3;
    free($3);
}
| SHOW TABLE table_name {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kTable;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
}
| SHOW TABLE table_name COLUMNS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kColumns;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
}
| SHOW TABLE table_name SEGMENTS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kSegments;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
}
| SHOW TABLE table_name SEGMENT LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kSegment;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    $$->segment_id_ = $5;
    delete $3;
}
| SHOW TABLE table_name SEGMENT LONG_VALUE BLOCKS {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kBlocks;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    $$->segment_id_ = $5;
    delete $3;
}
| SHOW TABLE table_name SEGMENT LONG_VALUE BLOCK LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kBlock;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    $$->segment_id_ = $5;
    $$->block_id_ = $7;
    delete $3;
}
| SHOW TABLE table_name SEGMENT LONG_VALUE BLOCK LONG_VALUE COLUMN LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kBlockColumn;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    $$->segment_id_ = $5;
    $$->block_id_ = $7;
    $$->column_id_ = $9;
    delete $3;
}
| SHOW TABLE table_name INDEXES {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kIndexes;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;
};
| SHOW TABLE table_name INDEX IDENTIFIER {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kIndex;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;

    $$->index_name_ = $5;
    free($5);
};
| SHOW TABLE table_name INDEX IDENTIFIER SEGMENT LONG_VALUE {
    $$ = new infinity::ShowStatement();
    $$->show_type_ = infinity::ShowStmtType::kIndexSegment;
    if($3->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $3->schema_name_ptr_;
        free($3->schema_name_ptr_);
    }
    $$->table_name_ = $3->table_name_ptr_;
    free($3->table_name_ptr_);
    delete $3;

    $$->index_name_ = $5;
    free($5);

    $$->segment_id_ = $7;
};
| SHOW TABLE table_name INDEX IDENTIFIER SEGMENT LONG_VALUE CHUNK LONG_VALUE {
      $$ = new infinity::ShowStatement();
      $$->show_type_ = infinity::ShowStmtType::kIndexChunk;
      if($3->schema_name_ptr_ != nullptr) {
          $$->schema_name_ = $3->schema_name_ptr_;
          free($3->schema_name_ptr_);
      }
      $$->table_name_ = $3->table_name_ptr_;
      free($3->table_name_ptr_);
      delete $3;

      $$->index_name_ = $5;
      free($5);

      $$->segment_id_ = $7;
      $$->chunk_id_ = $9;
  };

/*
 * FLUSH STATEMENT
 */
flush_statement: FLUSH DATA {
    $$ = new infinity::FlushStatement();
    $$->type_ = infinity::FlushType::kData;
}
| FLUSH LOG {
    $$ = new infinity::FlushStatement();
    $$->type_ = infinity::FlushType::kLog;
}
| FLUSH BUFFER {
    $$ = new infinity::FlushStatement();
    $$->type_ = infinity::FlushType::kBuffer;
};

/*
 * OPTIMIZE STATEMENT
 */
optimize_statement: OPTIMIZE table_name {
    $$ = new infinity::OptimizeStatement();
    if($2->schema_name_ptr_ != nullptr) {
        $$->schema_name_ = $2->schema_name_ptr_;
        free($2->schema_name_ptr_);
    }
    $$->table_name_ = $2->table_name_ptr_;
    free($2->table_name_ptr_);
    delete $2;
};

/*
 * Command
 */
command_statement: USE IDENTIFIER {
    $$ = new infinity::CommandStatement();
    ParserHelper::ToLower($2);
    $$->command_info_ = std::make_shared<infinity::UseCmd>($2);
    free($2);
}
| EXPORT PROFILE LONG_VALUE file_path {
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::ExportCmd>($4, infinity::ExportType::kProfileRecord, $3);
    free($4);
}
| SET SESSION IDENTIFIER ON {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kSession, infinity::SetVarType::kBool, $3, true);
    free($3);
}
| SET SESSION IDENTIFIER OFF {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kSession, infinity::SetVarType::kBool, $3, false);
    free($3);
}
| SET SESSION IDENTIFIER IDENTIFIER {
    ParserHelper::ToLower($3);
    ParserHelper::ToLower($4);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kSession, infinity::SetVarType::kString, $3, $4);
    free($3);
    free($4);
}
| SET SESSION IDENTIFIER LONG_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kSession, infinity::SetVarType::kInteger, $3, $4);
    free($3);
}
| SET SESSION IDENTIFIER DOUBLE_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kSession, infinity::SetVarType::kDouble, $3, $4);
    free($3);
};
| SET GLOBAL IDENTIFIER ON {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kGlobal, infinity::SetVarType::kBool, $3, true);
    free($3);
}
| SET GLOBAL IDENTIFIER OFF {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kGlobal, infinity::SetVarType::kBool, $3, false);
    free($3);
}
| SET GLOBAL IDENTIFIER IDENTIFIER {
    ParserHelper::ToLower($3);
    ParserHelper::ToLower($4);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kGlobal, infinity::SetVarType::kString, $3, $4);
    free($3);
    free($4);
}
| SET GLOBAL IDENTIFIER LONG_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kGlobal, infinity::SetVarType::kInteger, $3, $4);
    free($3);
}
| SET GLOBAL IDENTIFIER DOUBLE_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kGlobal, infinity::SetVarType::kDouble, $3, $4);
    free($3);
}
| SET CONFIG IDENTIFIER ON {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kConfig, infinity::SetVarType::kBool, $3, true);
    free($3);
}
| SET CONFIG IDENTIFIER OFF {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kConfig, infinity::SetVarType::kBool, $3, false);
    free($3);
}
| SET CONFIG IDENTIFIER IDENTIFIER {
    ParserHelper::ToLower($3);
    ParserHelper::ToLower($4);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kConfig, infinity::SetVarType::kString, $3, $4);
    free($3);
    free($4);
}
| SET CONFIG IDENTIFIER LONG_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kConfig, infinity::SetVarType::kInteger, $3, $4);
    free($3);
}
| SET CONFIG IDENTIFIER DOUBLE_VALUE {
    ParserHelper::ToLower($3);
    $$ = new infinity::CommandStatement();
    $$->command_info_ = std::make_shared<infinity::SetCmd>(infinity::SetScope::kConfig, infinity::SetVarType::kDouble, $3, $4);
    free($3);
}

compact_statement: COMPACT TABLE table_name {
    std::string schema_name;
    if ($3->schema_name_ptr_ != nullptr) {
        schema_name = std::string($3->schema_name_ptr_);
        free($3->schema_name_ptr_);
    }
    std::string table_name = std::string($3->table_name_ptr_);
    free($3->table_name_ptr_);

    $$ = new infinity::ManualCompactStatement(std::move(schema_name), std::move(table_name));
    delete $3;
}

/*
 * EXPRESSION
 */

expr_array : expr_alias {
    $$ = new std::vector<infinity::ParsedExpr*>();
    $$->emplace_back($1);
}
| expr_array ',' expr_alias {
    $1->emplace_back($3);
    $$ = $1;
};

expr_array_list : '(' expr_array ')' {
    $$ = new std::vector<std::vector<infinity::ParsedExpr*>*>();
    $$->push_back($2);
}
| expr_array_list ',' '(' expr_array ')' {
    if(!$1->empty() && $1->back()->size() != $4->size()) {
        yyerror(&yyloc, scanner, result, "The expr_array in list shall have the same size.");
        for (auto arr_ptr : *$1) {
            for (auto ptr : *arr_ptr) {
                delete ptr;
            }
            delete (arr_ptr);
        }
        delete $1;
        YYERROR;
    }
    $1->push_back($4);
    $$ = $1;
};

/*
constant_expr_array: constant_expr {
    $$ = new std::vector<infinity::ParsedExpr*>();
    $$->emplace_back($1);
}
| constant_expr_array ',' constant_expr {
    $1->emplace_back($3);
    $$ = $1;
}
*/

expr_alias : expr AS IDENTIFIER {
    $$ = $1;
    ParserHelper::ToLower($3);
    $$->alias_ = $3;
    free($3);
}
| expr {
    $$ = $1;
};

expr : operand
| subquery_expr
| in_expr
| between_expr
| conjunction_expr;

operand: '(' expr ')' {
    $$ = $2;
}
| '(' select_without_paren ')' {
    infinity::SubqueryExpr* subquery_expr = new infinity::SubqueryExpr();
    subquery_expr->subquery_type_ = infinity::SubqueryType::kScalar;
    subquery_expr->select_ = $2;
    $$ = subquery_expr;
}
| constant_expr {
    $$ = $1;
}
| column_expr
| function_expr
| case_expr
| cast_expr
| match_vector_expr
| match_text_expr
| match_tensor_expr
| match_sparse_expr
| query_expr
| fusion_expr

extra_match_tensor_option : ',' STRING {
    $$ = $2;
}
| {
    $$ = nullptr;
}

//                                       4                   6               8          10              11
//                  MATCH TENSOR  (  column_name,     search_tensor, tensor_data_type, search_method, extra_match_tensor_option(including topn))
match_tensor_expr : MATCH TENSOR '(' column_expr ',' common_array_expr ',' STRING ',' STRING extra_match_tensor_option ')' {
    auto match_tensor_expr = std::make_unique<infinity::MatchTensorExpr>();
    // search column
    match_tensor_expr->SetSearchColumn($4);
    // search tensor
    ParserHelper::ToLower($8);
    match_tensor_expr->SetQueryTensor($8, $6);
    // search method
    ParserHelper::ToLower($10);
    match_tensor_expr->SetSearchMethod($10);
    // search options
    if ($11) {
        match_tensor_expr->SetExtraOptions($11);
    }
    $$ = match_tensor_expr.release();
}

//                  MATCH VECTOR (column_name, query_vec, data_type, metric_type, topn        )  extra options
//                   1      2         4         6              8          10           12             14
match_vector_expr : MATCH VECTOR '(' expr ',' array_expr ',' STRING ',' STRING ',' LONG_VALUE ')' with_index_param_list {
    infinity::KnnExpr* match_vector_expr = new infinity::KnnExpr();
    $$ = match_vector_expr;

    // vector search column
    match_vector_expr->column_expr_ = $4;

    // vector distance type
    ParserHelper::ToLower($10);
    bool check = match_vector_expr->InitDistanceType($10);
    if (!check) {
        goto Error1;
    }

    // vector data type
    ParserHelper::ToLower($8);
    check = match_vector_expr->InitEmbedding($8, $6);
    if (!check) {
        goto Error1;
    }
    free($8);
    free($10);
    delete $6;

    match_vector_expr->topn_ = $12;
    match_vector_expr->opt_params_ = $14;
    goto Return1;
Error1:
    for (auto* param_ptr: *$14) {
        delete param_ptr;
    }
    delete $14;
    free($8);
    free($10);
    delete $6;
    delete $$;
    yyerror(&yyloc, scanner, result, "Invalid vector search distance type");
    YYERROR;
Return1:
    ;
}
|
MATCH VECTOR '(' expr ',' array_expr ',' STRING ',' STRING ')' with_index_param_list {
    infinity::KnnExpr* match_vector_expr = new infinity::KnnExpr();
    $$ = match_vector_expr;

    // vector search search column
    match_vector_expr->column_expr_ = $4;

    // vector search distance type
    ParserHelper::ToLower($10);
    bool check = match_vector_expr->InitDistanceType($10);
    if (!check) {
        goto Error2;
    }

    // vector search data type
    ParserHelper::ToLower($8);
    check = match_vector_expr->InitEmbedding($8, $6);
    if (!check) {
        goto Error2;
    }
    free($8);
    free($10);
    delete $6;

    match_vector_expr->topn_ = infinity::DEFAULT_MATCH_VECTOR_TOP_N;
    match_vector_expr->opt_params_ = $12;
    goto Return2;

Error2:
    for (auto* param_ptr: *$12) {
        delete param_ptr;
    }
    delete $12;
    free($8);
    free($10);
    delete $6;
    delete $$;
    yyerror(&yyloc, scanner, result, "Invalid vector search distance type");
    YYERROR;
Return2:
    ;
}


//                 MATCH SPARSE (column_name,       query_sparse,      metric_type,     topn)         extra options
//                   1      2         4                  6                   8           10                12
match_sparse_expr: MATCH SPARSE '(' expr ',' common_sparse_array_expr ',' STRING ',' LONG_VALUE ')' with_index_param_list {
    auto match_sparse_expr = new infinity::MatchSparseExpr();
    $$ = match_sparse_expr;

    // search column
    match_sparse_expr->SetSearchColumn($4);

    // search sparse and data type
    match_sparse_expr->SetQuerySparse($6);

    // metric type
    ParserHelper::ToLower($8);
    match_sparse_expr->SetMetricType($8);

    // topn and options
    match_sparse_expr->SetOptParams($10, $12);
}
|
MATCH SPARSE '(' expr ',' common_sparse_array_expr ',' STRING ')' with_index_param_list {
    auto match_sparse_expr = new infinity::MatchSparseExpr();
    $$ = match_sparse_expr;

    // search column
    match_sparse_expr->SetSearchColumn($4);

    // search sparse and data type
    match_sparse_expr->SetQuerySparse($6);

    // metric type
    ParserHelper::ToLower($8);
    match_sparse_expr->SetMetricType($8);

    // topn and options
    match_sparse_expr->SetOptParams(infinity::DEFAULT_MATCH_SPARSE_TOP_N, $10);
}

match_text_expr : MATCH TEXT '(' STRING ',' STRING ')' {
    infinity::MatchExpr* match_text_expr = new infinity::MatchExpr();
    match_text_expr->fields_ = std::string($4);
    match_text_expr->matching_text_ = std::string($6);
    free($4);
    free($6);
    $$ = match_text_expr;
}
| MATCH TEXT '(' STRING ',' STRING ',' STRING ')' {
    infinity::MatchExpr* match_text_expr = new infinity::MatchExpr();
    match_text_expr->fields_ = std::string($4);
    match_text_expr->matching_text_ = std::string($6);
    match_text_expr->options_text_ = std::string($8);
    free($4);
    free($6);
    free($8);
    $$ = match_text_expr;
}

query_expr : QUERY '(' STRING ')' {
    infinity::MatchExpr* match_text_expr = new infinity::MatchExpr();
    match_text_expr->matching_text_ = std::string($3);
    free($3);
    $$ = match_text_expr;
}
| QUERY '(' STRING ',' STRING ')' {
    infinity::MatchExpr* match_text_expr = new infinity::MatchExpr();
    match_text_expr->matching_text_ = std::string($3);
    match_text_expr->options_text_ = std::string($5);
    free($3);
    free($5);
    $$ = match_text_expr;
}

fusion_expr : FUSION '(' STRING ')' {
    infinity::FusionExpr* fusion_expr = new infinity::FusionExpr();
    fusion_expr->method_ = std::string($3);
    free($3);
    $$ = fusion_expr;
}
| FUSION '(' STRING ',' STRING ')' {
    auto fusion_expr = std::make_unique<infinity::FusionExpr>();
    fusion_expr->method_ = std::string($3);
    free($3);
    $3 = nullptr;
    fusion_expr->SetOptions($5);
    free($5);
    $5 = nullptr;
    fusion_expr->JobAfterParser();
    $$ = fusion_expr.release();
}

sub_search : match_vector_expr {
    $$ = $1;
}
| match_text_expr {
    $$ = $1;
}
| match_tensor_expr {
    $$ = $1;
}
| match_sparse_expr {
    $$ = $1;
}
| query_expr {
    $$ = $1;
}
| fusion_expr {
    $$ = $1;
}

sub_search_array : sub_search {
    $$ = new std::vector<infinity::ParsedExpr*>();
    $$->emplace_back($1);
}
| sub_search_array ',' sub_search {
    $1->emplace_back($3);
    $$ = $1;
};

function_expr : IDENTIFIER '(' ')' {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    ParserHelper::ToLower($1);
    func_expr->func_name_ = $1;
    free($1);
    func_expr->arguments_ = nullptr;
    $$ = func_expr;
}
| IDENTIFIER '(' expr_array ')' {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    ParserHelper::ToLower($1);
    func_expr->func_name_ = $1;
    free($1);
    func_expr->arguments_ = $3;
    $$ = func_expr;
}
| IDENTIFIER '(' DISTINCT expr_array ')' {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    ParserHelper::ToLower($1);
    func_expr->func_name_ = $1;
    free($1);
    func_expr->arguments_ = $4;
    func_expr->distinct_ = true;
    $$ = func_expr;
}
| operand IS NOT NULLABLE {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "is_not_null";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    $$ = func_expr;
}
| operand IS NULLABLE {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "is_null";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    $$ = func_expr;
}
| NOT operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "not";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($2);
    $$ = func_expr;
}
| '-' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "-";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($2);
    $$ = func_expr;
}
| '+' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "+";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($2);
    $$ = func_expr;
}
| operand '-' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "-";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '+' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "+";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '*' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "*";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '/' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "/";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '%' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "%";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '=' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "=";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand EQUAL operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "=";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand NOT_EQ operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "<>";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '<' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "<";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand '>' operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = ">";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand LESS_EQ operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "<=";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand GREATER_EQ operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = ">=";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| EXTRACT '(' STRING FROM operand ')' {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    ParserHelper::ToLower($3);
    if(strcmp($3, "year") == 0) {
        func_expr->func_name_ = "extract_year";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else if(strcmp($3, "month") == 0) {
        func_expr->func_name_ = "extract_month";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else if(strcmp($3, "day") == 0) {
        func_expr->func_name_ = "extract_day";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else if(strcmp($3, "hour") == 0) {
        func_expr->func_name_ = "extract_hour";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else if(strcmp($3, "minute") == 0) {
        func_expr->func_name_ = "extract_minute";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else if(strcmp($3, "second") == 0) {
        func_expr->func_name_ = "extract_second";
        func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    } else {
        delete func_expr;
        yyerror(&yyloc, scanner, result, "Invalid column expression format");
        YYERROR;
    }
    free($3);
    func_expr->arguments_->emplace_back($5);
    $$ = func_expr;
}
| operand LIKE operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "like";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| operand NOT LIKE operand {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "not_like";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($4);
    $$ = func_expr;
};

conjunction_expr: expr AND expr {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "and";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
}
| expr OR expr {
    infinity::FunctionExpr* func_expr = new infinity::FunctionExpr();
    func_expr->func_name_ = "or";
    func_expr->arguments_ = new std::vector<infinity::ParsedExpr*>();
    func_expr->arguments_->emplace_back($1);
    func_expr->arguments_->emplace_back($3);
    $$ = func_expr;
};

between_expr: operand BETWEEN operand AND operand {
    infinity::BetweenExpr* between_expr = new infinity::BetweenExpr();
    between_expr->value_ = $1;
    between_expr->lower_bound_ = $3;
    between_expr->upper_bound_ = $5;
    $$ = between_expr;
}

in_expr: operand IN '(' expr_array ')' {
    infinity::InExpr* in_expr = new infinity::InExpr(true);
    in_expr->left_ = $1;
    in_expr->arguments_ = $4;
    $$ = in_expr;
}
| operand NOT IN '(' expr_array ')' {
    infinity::InExpr* in_expr = new infinity::InExpr(false);
    in_expr->left_ = $1;
    in_expr->arguments_ = $5;
    $$ = in_expr;
};

case_expr: CASE expr case_check_array END {
    infinity::CaseExpr* case_expr = new infinity::CaseExpr();
    case_expr->expr_ = $2;
    case_expr->case_check_array_ = $3;
    $$ = case_expr;
}
| CASE expr case_check_array ELSE expr END {
    infinity::CaseExpr* case_expr = new infinity::CaseExpr();
    case_expr->expr_ = $2;
    case_expr->case_check_array_ = $3;
    case_expr->else_expr_ = $5;
    $$ = case_expr;
}
| CASE case_check_array END {
    infinity::CaseExpr* case_expr = new infinity::CaseExpr();
    case_expr->case_check_array_ = $2;
    $$ = case_expr;
}
| CASE case_check_array ELSE expr END {
    infinity::CaseExpr* case_expr = new infinity::CaseExpr();
    case_expr->case_check_array_ = $2;
    case_expr->else_expr_ = $4;
    $$ = case_expr;
};

case_check_array: WHEN expr THEN expr {
    $$ = new std::vector<infinity::WhenThen*>();
    infinity::WhenThen* when_then_ptr = new infinity::WhenThen();
    when_then_ptr->when_ = $2;
    when_then_ptr->then_ = $4;
    $$->emplace_back(when_then_ptr);
}
| case_check_array WHEN expr THEN expr {
    infinity::WhenThen* when_then_ptr = new infinity::WhenThen();
    when_then_ptr->when_ = $3;
    when_then_ptr->then_ = $5;
    $1->emplace_back(when_then_ptr);
    $$ = $1;
};

cast_expr: CAST '(' expr AS column_type ')' {
    std::shared_ptr<infinity::TypeInfo> type_info_ptr{nullptr};
    switch($5.logical_type_) {
        case infinity::LogicalType::kDecimal: {
            type_info_ptr = infinity::DecimalInfo::Make($5.precision, $5.scale);
            break;
        }
//        case infinity::LogicalType::kBitmap: {
//            type_info_ptr = infinity::BitmapInfo::Make($5.width);
//            break;
//        }
        case infinity::LogicalType::kEmbedding: {
            type_info_ptr = infinity::EmbeddingInfo::Make($5.embedding_type_, $5.width);
            break;
        }
        default: {
            break;
        }
    }
    infinity::CastExpr* cast_expr = new infinity::CastExpr($5.logical_type_, type_info_ptr);
    cast_expr->expr_ = $3;
    $$ = cast_expr;
};

subquery_expr: EXISTS '(' select_without_paren ')' {
    infinity::SubqueryExpr* subquery_expr = new infinity::SubqueryExpr();
    subquery_expr->subquery_type_ = infinity::SubqueryType::kExists;
    subquery_expr->select_ = $3;
    $$ = subquery_expr;
}
| NOT EXISTS '(' select_without_paren ')' {
    infinity::SubqueryExpr* subquery_expr = new infinity::SubqueryExpr();
    subquery_expr->subquery_type_ = infinity::SubqueryType::kNotExists;
    subquery_expr->select_ = $4;
    $$ = subquery_expr;
}
| operand IN '(' select_without_paren ')' {
    infinity::SubqueryExpr* subquery_expr = new infinity::SubqueryExpr();
    subquery_expr->subquery_type_ = infinity::SubqueryType::kIn;
    subquery_expr->left_ = $1;
    subquery_expr->select_ = $4;
    $$ = subquery_expr;
}
| operand NOT IN '(' select_without_paren ')' {
    infinity::SubqueryExpr* subquery_expr = new infinity::SubqueryExpr();
    subquery_expr->subquery_type_ = infinity::SubqueryType::kNotIn;
    subquery_expr->left_ = $1;
    subquery_expr->select_ = $5;
    $$ = subquery_expr;
};

column_expr : IDENTIFIER {
    infinity::ColumnExpr* column_expr = new infinity::ColumnExpr();
    ParserHelper::ToLower($1);
    column_expr->names_.emplace_back($1);
    free($1);
    $$ = column_expr;
}
| column_expr '.' IDENTIFIER {
    infinity::ColumnExpr* column_expr = (infinity::ColumnExpr*)$1;
    ParserHelper::ToLower($3);
    column_expr->names_.emplace_back($3);
    free($3);
    $$ = column_expr;
}
| '*' {
    infinity::ColumnExpr* column_expr = new infinity::ColumnExpr();
    column_expr->star_ = true;
    $$ = column_expr;
}
| column_expr '.' '*' {
    infinity::ColumnExpr* column_expr = (infinity::ColumnExpr*)$1;
    if(column_expr->star_) {
        yyerror(&yyloc, scanner, result, "Invalid column expression format");
        YYERROR;
    }
    column_expr->star_ = true;
    $$ = column_expr;
};

constant_expr: STRING {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kString);
    const_expr->str_value_ = $1;
    $$ = const_expr;
}
| TRUE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kBoolean);
    const_expr->bool_value_ = true;
    $$ = const_expr;
}
| FALSE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kBoolean);
    const_expr->bool_value_ = false;
    $$ = const_expr;
}
| DOUBLE_VALUE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kDouble);
    const_expr->double_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInteger);
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| DATE STRING {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kDate);
    const_expr->date_value_ = $2;
    $$ = const_expr;
}
| TIME STRING {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kTime);
    const_expr->date_value_ = $2;
    $$ = const_expr;
}
| DATETIME STRING {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kDateTime);
    const_expr->date_value_ = $2;
    $$ = const_expr;
}
| TIMESTAMP STRING {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kTimestamp);
    const_expr->date_value_ = $2;
    $$ = const_expr;
}
| INTERVAL interval_expr {
    $$ = $2;
}
| interval_expr {
    $$ = $1;
}
| common_array_expr {
    $$ = $1;
}

common_array_expr: array_expr {
    $$ = $1;
}
| subarray_array_expr {
    $$ = $1;
}
| sparse_array_expr {
    $$ = $1;
}
| empty_array_expr {
    $$ = $1;
}

common_sparse_array_expr: sparse_array_expr {
    $$ = $1;
}
| array_expr {
    $$ = $1;
}
| empty_array_expr {
    $$ = $1;
}

subarray_array_expr: unclosed_subarray_array_expr ']' {
    $$ = $1;
};

unclosed_subarray_array_expr: '[' common_array_expr {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kSubArrayArray);
    const_expr->sub_array_array_.emplace_back($2);
    $$ = const_expr;
}
| unclosed_subarray_array_expr ',' common_array_expr {
    $1->sub_array_array_.emplace_back($3);
    $$ = $1;
}

sparse_array_expr: long_sparse_array_expr {
    $$ = $1;
}
| double_sparse_array_expr {
    $$ = $1;
}

long_sparse_array_expr: unclosed_long_sparse_array_expr ']' {
    $$ = $1;
}

unclosed_long_sparse_array_expr: '[' int_sparse_ele {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kLongSparseArray);
    const_expr->long_sparse_array_.first.emplace_back($2->first);
    const_expr->long_sparse_array_.second.emplace_back($2->second);
    delete $2;
    $$ = const_expr;
}
| unclosed_long_sparse_array_expr ',' int_sparse_ele {
    $1->long_sparse_array_.first.emplace_back($3->first);
    $1->long_sparse_array_.second.emplace_back($3->second);
    delete $3;
    $$ = $1;
}

double_sparse_array_expr: unclosed_double_sparse_array_expr ']' {
    $$ = $1;
}

unclosed_double_sparse_array_expr: '[' float_sparse_ele {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kDoubleSparseArray);
    const_expr->double_sparse_array_.first.emplace_back($2->first);
    const_expr->double_sparse_array_.second.emplace_back($2->second);
    delete $2;
    $$ = const_expr;
}
| unclosed_double_sparse_array_expr ',' float_sparse_ele {
    $1->double_sparse_array_.first.emplace_back($3->first);
    $1->double_sparse_array_.second.emplace_back($3->second);
    delete $3;
    $$ = $1;
}

empty_array_expr: '[' ']' {
    $$ = new infinity::ConstantExpr(infinity::LiteralType::kEmptyArray);
}

int_sparse_ele: LONG_VALUE ':' LONG_VALUE {
    $$ = new std::pair<int64_t, int64_t>{$1, $3};
}

float_sparse_ele: LONG_VALUE ':' DOUBLE_VALUE {
    $$ = new std::pair<int64_t, double>{$1, $3};
}

array_expr: long_array_expr {
    $$ = $1;
}
| double_array_expr {
    $$ = $1;
}

long_array_expr: unclosed_long_array_expr ']' {
    $$ = $1;
};

unclosed_long_array_expr: '[' LONG_VALUE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kIntegerArray);
    const_expr->long_array_.emplace_back($2);
    $$ = const_expr;
}
| unclosed_long_array_expr ',' LONG_VALUE {
    $1->long_array_.emplace_back($3);
    $$ = $1;
}

double_array_expr: unclosed_double_array_expr ']' {
    $$ = $1;
};

unclosed_double_array_expr: '[' DOUBLE_VALUE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kDoubleArray);
    const_expr->double_array_.emplace_back($2);
    $$ = const_expr;
}
| unclosed_double_array_expr ',' DOUBLE_VALUE {
    $1->double_array_.emplace_back($3);
    $$ = $1;
}

interval_expr: LONG_VALUE SECONDS {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kSecond;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE SECOND {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kSecond;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE MINUTES {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kMinute;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE MINUTE {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kMinute;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE HOURS {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kHour;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE HOUR {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kHour;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE DAYS {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kDay;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE DAY {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kDay;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE MONTHS {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kMonth;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE MONTH {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kMonth;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE YEARS {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kYear;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
}
| LONG_VALUE YEAR {
    infinity::ConstantExpr* const_expr = new infinity::ConstantExpr(infinity::LiteralType::kInterval);
    const_expr->interval_type_ = infinity::TimeUnit::kYear;
    const_expr->integer_value_ = $1;
    $$ = const_expr;
};

/*
 * Misc.
 */

copy_option_list : copy_option {
    $$ = new std::vector<infinity::CopyOption*>();
    $$->push_back($1);
}
| copy_option_list ',' copy_option {
    $1->push_back($3);
    $$ = $1;
};

copy_option : FORMAT IDENTIFIER {
    $$ = new infinity::CopyOption();
    $$->option_type_ = infinity::CopyOptionType::kFormat;
    if (strcasecmp($2, "csv") == 0) {
        $$->file_type_ = infinity::CopyFileType::kCSV;
        free($2);
    } else if (strcasecmp($2, "json") == 0) {
        $$->file_type_ = infinity::CopyFileType::kJSON;
        free($2);
    } else if (strcasecmp($2, "jsonl") == 0) {
        $$->file_type_ = infinity::CopyFileType::kJSONL;
        free($2);
    } else if (strcasecmp($2, "fvecs") == 0) {
        $$->file_type_ = infinity::CopyFileType::kFVECS;
        free($2);
    } else if (strcasecmp($2, "csr") == 0) {
        $$->file_type_ = infinity::CopyFileType::kCSR;
        free($2);
    } else if (strcasecmp($2, "bvecs") == 0) {
        $$->file_type_ = infinity::CopyFileType::kBVECS;
        free($2);
    } else {
        free($2);
        delete $$;
        yyerror(&yyloc, scanner, result, "Unknown file format");
        YYERROR;
    }
}
| DELIMITER STRING {
    $$ = new infinity::CopyOption();
    $$->option_type_ = infinity::CopyOptionType::kDelimiter;
    if(strlen($2) > 1 && $2[0] == '\\') {
        if($2[1] == 't') $$->delimiter_ = '\t';
    }else {
        $$->delimiter_ = $2[0];
    }
    free($2);
}
| HEADER {
    $$ = new infinity::CopyOption();
    $$->option_type_ = infinity::CopyOptionType::kHeader;
    $$->header_ = true;
};

file_path : STRING {
    $$ = $1;
};

if_exists: IF EXISTS { $$ = true; }
| { $$ = false; };

if_not_exists : IF NOT EXISTS { $$ = true; }
| { $$ = false; };

semicolon : ';'
| /* nothing */
;

/* if_exists_info : if_exists IDENTIFIER {
    $$ = new infinity::IfExistsInfo();
    $$->exists_ = true;
    $$->if_exists_ = $1;
    ParserHelper::ToLower($2);
    $$->info_ = $2;
    free($2);
} */

if_not_exists_info : if_not_exists IDENTIFIER {
    $$ = new infinity::IfNotExistsInfo();
    $$->exists_ = true;
    $$->if_not_exists_ = $1;
    ParserHelper::ToLower($2);
    $$->info_ = $2;
    free($2);
}
| {
    $$ = new infinity::IfNotExistsInfo();
}

with_index_param_list : WITH '(' index_param_list ')' {
    $$ = $3;
}
| {
    $$ = new std::vector<infinity::InitParameter*>();
}

optional_table_properties_list : PROPERTIES '(' index_param_list ')' {
    $$ = $3;
}
| {
    $$ = nullptr;
}

index_param_list : index_param {
    $$ = new std::vector<infinity::InitParameter*>();
    $$->push_back($1);
}
| index_param_list ',' index_param {
    $1->push_back($3);
    $$ = $1;
};

index_param : IDENTIFIER {
    ParserHelper::ToLower($1);
    $$ = new infinity::InitParameter();
    $$->param_name_ = $1;
    free($1);
}
| IDENTIFIER '=' IDENTIFIER {
    ParserHelper::ToLower($1);
    ParserHelper::ToLower($3);
    $$ = new infinity::InitParameter();
    $$->param_name_ = $1;
    free($1);

    $$->param_value_ = $3;
    free($3);
}
| IDENTIFIER '=' LONG_VALUE {
    $$ = new infinity::InitParameter();
    $$->param_name_ = $1;
    free($1);

    $$->param_value_ = std::to_string($3);
}
| IDENTIFIER '=' DOUBLE_VALUE {
    $$ = new infinity::InitParameter();
    $$->param_name_ = $1;
    free($1);

    $$->param_value_ = std::to_string($3);
};

/* CREATE INDEX [[IF NOT EXISTS] index_name] ON table_name
(column1[, ...column2]) USING method [WITH (param[, ...param])] (column1[, ...column2]) USING method [WITH (param[, ...param])]; */

index_info_list : '(' identifier_array ')' USING IDENTIFIER with_index_param_list {
    ParserHelper::ToLower($5);
    infinity::IndexType index_type = infinity::IndexType::kInvalid;
    if(strcmp($5, "fulltext") == 0) {
        index_type = infinity::IndexType::kFullText;
    } else if (strcmp($5, "hnsw") == 0) {
        index_type = infinity::IndexType::kHnsw;
    } else if (strcmp($5, "bmp") == 0) {
        index_type = infinity::IndexType::kBMP;
    } else if (strcmp($5, "ivfflat") == 0) {
        index_type = infinity::IndexType::kIVFFlat;
    } else if (strcmp($5, "emvb") == 0) {
        index_type = infinity::IndexType::kEMVB;
    } else {
        free($5);
        delete $2;
        delete $6;
        yyerror(&yyloc, scanner, result, "Unknown index type");
        YYERROR;
    }
    free($5);

    size_t index_count = $2->size();
    if(index_count == 0) {
        delete $2;
        delete $6;
    }
    $$ = new std::vector<infinity::IndexInfo*>();
    $$->reserve(index_count);

    infinity::IndexInfo* index_info = new infinity::IndexInfo();
    index_info->index_type_ = index_type;
    index_info->column_name_ = (*$2)[0];
    index_info->index_param_list_ = $6;
    $$->emplace_back(index_info);

    for(size_t idx = 1; idx < index_count; ++ idx) {
        infinity::IndexInfo* index_info = new infinity::IndexInfo();
        index_info->index_type_ = index_type;
        index_info->column_name_ = (*$2)[idx];

        size_t param_count = $6->size();
        index_info->index_param_list_ = new std::vector<infinity::InitParameter*>();
        index_info->index_param_list_->resize(param_count);
        for(size_t param_idx = 0; param_idx < param_count; ++ param_idx) {
            (*(index_info->index_param_list_))[param_idx] = new infinity::InitParameter();
            *(*(index_info->index_param_list_))[param_idx] = *(*$6)[param_idx];
        }
        $$->emplace_back(index_info);
    }
    delete $2;
}
| index_info_list '(' identifier_array ')' USING IDENTIFIER with_index_param_list {
    ParserHelper::ToLower($6);
    infinity::IndexType index_type = infinity::IndexType::kInvalid;
    if(strcmp($6, "fulltext") == 0) {
        index_type = infinity::IndexType::kFullText;
    } else if (strcmp($6, "hnsw") == 0) {
        index_type = infinity::IndexType::kHnsw;
    } else if (strcmp($6, "ivfflat") == 0) {
        index_type = infinity::IndexType::kIVFFlat;
    } else {
        free($6);
        delete $3;
        delete $7;
        yyerror(&yyloc, scanner, result, "Unknown index type");
        YYERROR;
    }
    free($6);

    size_t index_count = $3->size();
    if(index_count == 0) {
        delete $1;
        delete $3;
        delete $7;
    }
    $$ = $1;
    $$->reserve($$->size() + index_count);

    infinity::IndexInfo* index_info = new infinity::IndexInfo();
    index_info->index_type_ = index_type;
    index_info->column_name_ = (*$3)[0];
    index_info->index_param_list_ = $7;
    $$->emplace_back(index_info);

    for(size_t idx = 1; idx < index_count; ++ idx) {
        infinity::IndexInfo* index_info = new infinity::IndexInfo();
        index_info->index_type_ = index_type;
        index_info->column_name_ = (*$3)[idx];

        size_t param_count = $7->size();
        index_info->index_param_list_ = new std::vector<infinity::InitParameter*>();
        index_info->index_param_list_->resize(param_count);
        for(size_t param_idx = 0; param_idx < param_count; ++ param_idx) {
            (*(index_info->index_param_list_))[param_idx] = new infinity::InitParameter();
            *(*(index_info->index_param_list_))[param_idx] = *(*$7)[param_idx];
        }
        $$->emplace_back(index_info);
    }
    delete $3;
}
| '(' identifier_array ')' {
    infinity::IndexType index_type = infinity::IndexType::kSecondary;
    size_t index_count = $2->size();
    $$ = new std::vector<infinity::IndexInfo*>();
    $$->reserve(index_count);
    for(size_t idx = 0; idx < index_count; ++ idx) {
        infinity::IndexInfo* index_info = new infinity::IndexInfo();
        index_info->index_type_ = index_type;
        index_info->column_name_ = (*$2)[idx];
        $$->emplace_back(index_info);
    }
    delete $2;
}

%%

void
yyerror(YYLTYPE * llocp, void* lexer, infinity::ParserResult* result, const char* msg) {
    if(result->IsError()) return ;

    result->error_message_ = std::string(msg) + ", " + std::to_string(llocp->first_column);
	fprintf(stderr, "Error: %s, %d:%d\n", msg, llocp->first_line, llocp->first_column);
}
