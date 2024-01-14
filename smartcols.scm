#! /usr/bin/env guile
!#

;;; module smartcols provide bindings to the smartcols library. It allows
;;; you to defined tables and print them from guile programmaticaly.
;;; The module wraps the underlying pointers so that they are available as values.
;;; The module wraps the underlying functions so that they are available as procedures.
;;; Procedures exposed by the module work on values instead of raw pointers.

;;; Copyright 2023 Edoardo Putti
;;; Released under the GPLv3 license

;;; TODO(edoput) define-smartcols-ffi macro
;;; TODO(edoput) define-smartcols-ffi should handle wrapped pointers
;;; TODO(edoput) define-smartcols-ffi should handle int as return type to raise error
;;; TODO(edoput) new-line! and new-column! return the newly created pointer, should return void?
;;; TODO(edoput) table-set-stream! and FILE* implementation in terms of ports
;;; TODO(edoput) unify new-line! and new-line-child! with default parameter

(define-module (smartcols)
  #:use-module (ice-9 iconv)
  #:use-module (rnrs bytevectors)
  #:use-module (system foreign)
  #:use-module (system foreign-library)
  #:export (make-table
	    empty?
	    height
	    width
	    acii?
	    colored?
	    maximised?
	    raw?
	    tree?
	    get-line
	    get-column
	    set-ascii!
	    set-colored!
	    set-export!

	    ;; table manipulation
	    new-column!
	    remove-column!
	    remove-columns!
	    add-line!
	    new-line!
	    new-line-child!
	    remove-line!
	    remove-lines!

	    make-column
	    column?
	    
	    make-line
	    line?
	    leaf?
	    color
	    parent
	    remove-child!
	    set-color!
	    set-data!

	    print-table))

(define libsmartcols (dynamic-link "libsmartcols"))

;;; wrapped pointers
(define-wrapped-pointer-type table
  table?
  wrap-table unwrap-table
  (lambda (t p)
    (format p "#<table of ~a>"
	    (pointer-address (unwrap-table t)))))

(define-wrapped-pointer-type column
  column?
  wrap-column unwrap-column
  (lambda (c p)
    (format p "#<column of ~a>"
	    (pointer-address (unwrap-column c)))))

(define-wrapped-pointer-type line
  line?
  wrap-line unwrap-line
  (lambda (l p)
    (format p "#<line of ~a>"
	    (pointer-address (unwrap-line l)))))
;;; ffi

;;; table manipulation
(define make-table-ffi
  (foreign-library-function libsmartcols
			    "scols_new_table"
			    #:return-type '*
			    #:arg-types '()))

(define (make-table)
  "Creates and returns a new table instance."
  (wrap-table (make-table-ffi)))


(define table-empty?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_empty"
			    #:return-type int
			    #:arg-types '(*)))
(define (empty? table)
  "Returns #t if table is empty."
  (= 1 (table-empty?-ffi (unwrap-table table))))

(define table-width-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_ncols"
			    #:return-type int
			    #:arg-types '(*)))
(define (width table)
  "Returns the table's width."
  (table-width-ffi (unwrap-table table)))

(define table-height-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_nlines"
			    #:return-type int
			    #:arg-types '(*)))

(define (height table)
  "Returns the table's height."
  (table-height-ffi (unwrap-table table)))


(define table-ascii?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_ascii"
			    #:return-type int
			    #:arg-types '(*)))

(define (ascii? table)
  "Returns #t if using ASCII characters for tree-like outputs."
  (= 1 (table-ascii?-ffi (unwrap-table table))))

(define table-maximised?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_maxout"
			    #:return-type int
			    #:arg-types '(*)))

(define (maximised? table)
  "Returns #t is the table is set to maximised."
  (= 1 (table-maximised?-ffi (unwrap-table table))))

;;; Parsable output formats
;;; libsmartcols supports exporting a table in different parseable formats.
;;; Currently there is implemented support for raw, export, and JSON format.
;;; The formats are mutually exclusive.

;;; raw output format
(define table-raw?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_raw"
			    #:return-type int
			    #:arg-types '(*)))

(define (raw? table)
  "Returns #t if the table is set to raw output format."
  (= 1 (table-raw?-ffi (unwrap-table table))))

;;; export output format
(define table-enabled-export-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_export"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-export! table enabled)
  "Enable/disable export format."
  (table-enabled-export-ffi (unwrap-table table) (if enabled 1 0)))

;;; JSON output format
(define table-enabled-json-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_json"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-json! table enabled)
  (table-enabled-export-ffi (unwrap-table table) (if enabled 1 0)))


(define table-tree?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_tree"
			    #:return-type int
			    #:arg-types '(*)))

(define (tree? table)
  "Returns #t if the table is a tree."
  (= 1 (table-tree?-ffi (unwrap-table table))))

(define table-colored?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_colors_wanted"
			    #:return-type int
			    #:arg-types '(*)))

(define (colored? table)
  "Returns #t if the table is set to colored."
  (= 1 (table-colored?-ffi table)))

(define table-enable-colors-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_colors"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-colored! table enabled)
  "Enable/disable colored output."
  (table-enable-colors-ffi (unwrap-table table) (if enabled 1 0)))


(define table-enabled-ascii-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_ascii"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-ascii! table enabled)
  "Enable/disable ASCII output."
  (table-enabled-ascii-ffi (unwrap-table table) (if enabled 1 0)))

(define table-get-stream-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_stream"
			    #:return-type '*
			    #:arg-types '(*)))

(define table-set-stream-ffi
  (foreign-library-function libsmartcols
			    "scols_table_set_stream"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define print-table-ffi
  (foreign-library-function libsmartcols
			    "scols_print_table"
			    #:return-type int
			    #:arg-types '(*)))
(define (print-table table)
  (print-table-ffi (unwrap-table table)))

;;; table lines
(define get-table-line-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_line"
			    #:return-type '*
			    #:arg-types (list '* size_t)))

(define (get-line table nth)
  "Returns the nth line of table."
  (wrap-line (get-table-line-ffi (unwrap-table table) nth)))

(define table-new-line-ffi
  (foreign-library-function libsmartcols
			    "scols_table_new_line"
			    #:return-type '*
			    #:arg-types (list '* '*)))

(define table-add-line-ffi
  (foreign-library-function libsmartcols
			    "scols_table_add_line"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (new-line! table)
  "Creates a new line for table and returns it."
  (wrap-line
   (table-new-line-ffi (unwrap-table table)
		       %null-pointer)))

(define (new-line-child! table parent-line)
  "Creates a new line for table as a child of parent-line and returns it."
  (wrap-line
   (table-new-line-ffi (unwrap-table table)
		       (unwrap-line parent-line))))

(define (add-line! table line)
  "Adds line to table."
  (table-add-line-ffi (unwrap-table table) (unwrap-line line)))

(define remove-line-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_line"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (remove-line! table line)
  "Removes line from table."
  (remove-line-ffi (unwrap-table table)
		   (unwrap-line line)))

(define remove-lines-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_lines"
			    #:return-type int
			    #:arg-types '(*)))

(define (remove-lines! table)
  "Removes all lines from table."
  (remove-lines-ffi (unwrap-table table)))

(define get-table-column-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_column"
			    #:return-type '*
			    #:arg-types (list '* size_t)))

(define (get-column table nth)
  "Returns the nth column from table."
  (wrap-column (get-table-column-ffi (unwrap-table table) nth)))

(define make-table-column-ffi
  (foreign-library-function libsmartcols
			    "scols_table_new_column"
			    #:return-type '*
			    #:arg-types (list '* '* double int)))

(define (new-column! table name width flags)
  "Creates a new column for table with the attributes name, width, flags."
  (wrap-column
   (make-table-column-ffi (unwrap-table table)
			  (string->pointer name)
			  width
			  flags)))

(define remove-column-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_column"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (remove-column! table column)
  "Removes column from table."
  (remove-column-ffi (unwrap-table table)
		     (unwrap-column column)))


(define remove-columns-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_columns"
			    #:return-type int
			    #:arg-types '(*)))

(define (remove-columns! table)
  "Removes all columns from table."
  (remove-columns-ffi (unwrap-table table)))

;;; column manipulation
(define make-column-ffi
  (foreign-library-function libsmartcols
			    "scols_new_column"
			    #:return-type '*
			    #:arg-types '()))


(define (make-column)
  "Creates and returns a column."
  (wrap-column (make-column-ffi)))


;;; line manipulation

(define make-line-ffi
  (foreign-library-function libsmartcols
			    "scols_new_line"
			    #:return-type '*
			    #:arg-types '()))

(define (make-line)
  "Creates and returns a line."
  (wrap-line (make-line-ffi)))

(define line-color-ffi
  (foreign-library-function libsmartcols
			    "scols_line_get_color"
			    #:return-type '*
			    #:arg-types '(*)))

(define (color line)
  "Returns a string value representing the color of line."
  (pointer->string (line-color-ffi (unwrap-line line))))

(define line-set-color-ffi
  (foreign-library-function libsmartcols
			    "scols_line_set_color"
			    #:return-type int
			    #:arg-types '(* *)))

(define (set-color! line color)
  "Set the line color to the value represented by the string value color."
  (line-set-color-ffi (unwrap-line line) (string->pointer color "ascii")))

(define line-parent-ffi
  (foreign-library-function libsmartcols
			    "scols_line_get_parent"
			    #:return-type '*
			    #:arg-types '(*)))

(define (line-parent line)
  "Returns the parent of line."
  (wrap-line (line-parent-ffi (unwrap-line line))))

(define line-leaf-ffi
  (foreign-library-function libsmartcols
			    "scols_line_has_children"
			    #:return-type int
			    #:arg-types '(*)))

(define (leaf? line)
  "Returns #t if line is a leaf."
  (= 0 (line-leaf-ffi (unwrap-line line))))

(define remove-line-child-ffi
  (foreign-library-function libsmartcols
			    "scols_line_remove_child"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (remove-child! parent-line child-line)
  "Removes the parent-child relation between parent-line and child-line."
  (remove-line-child-ffi (unwrap-line parent-line)
			 (unwrap-line child-line)))

(define line-set-data-ffi
  (foreign-library-function libsmartcols
			    "scols_line_set_data"
			    #:return-type int
			    #:arg-types (list '* size_t '*)))

(define line-set-column-data-ffi
  (foreign-library-function libsmartcols
			    "scols_line_set_column_data"
			    #:return-type int
			    #:arg-types '(* * *)))

(define (set-line-column-data! line column data)
  "Set the cell at the intersection line, column to hold the string value data. "
  (cond
   ;; by offset
   [(integer? column)
    (line-set-data-ffi (unwrap-line line)
		       column
		       (string->pointer data))]
   [else
    ;; by column object
    (line-set-column-data-ffi (unwrap-line line)
			      (unwrap-column column)
			      (string->pointer data))]))

(define-syntax set-data!
  (syntax-rules ()
    [(_ line (column-index data))
     (set-line-column-data! line column-index data)]
    [(_ line (column-index data) rest ...)
     (begin
       (set-line-column-data! line column-index data)
       (set-line-data! line rest ...))]))

;;; tests
(define init-debug
  (foreign-library-function libsmartcols
			    "scols_init_debug"
			    #:return-type void
			    #:arg-types (list int)))

;;; TODO(edoput) this requires going through FILE*. I'm not sure how to go through this.
(define (table->string table)
  "Returns the string representation of table."
  (with-output-to-string 
    (λ ()
      (let [(previous (table-get-stream-ffi (unwrap-table table)))] ;TODO(edoput) replace with dynamic-wind
	(table-set-stream-ffi (unwrap-table table) (port->fdes (current-output-port)))	
	(print-table-ffi (unwrap-table table))
	(table-set-stream-ffi (unwrap-table table) (previous))))))
