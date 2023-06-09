#! /usr/bin/env guile
!#

;;; Copyright 2023 Edoardo Putti
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

(define (make-table) (wrap-table (make-table-ffi)))


(define table-empty?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_empty"
			    #:return-type int
			    #:arg-types '(*)))
(define (empty? table)
  (= 1 (table-empty?-ffi (unwrap-table table))))

(define table-width-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_ncols"
			    #:return-type int
			    #:arg-types '(*)))
(define (width table)
  (table-width-ffi (unwrap-table table)))

(define table-height-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_nlines"
			    #:return-type int
			    #:arg-types '(*)))

(define (height table)
  (table-height-ffi (unwrap-table table)))


(define table-ascii?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_ascii"
			    #:return-type int
			    #:arg-types '(*)))

(define (ascii? table)
  (= 1 (table-ascii?-ffi (unwrap-table table))))

(define table-maximised?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_maxout"
			    #:return-type int
			    #:arg-types '(*)))

(define (maximised? table)
  (= 1 (table-maximised?-ffi (unwrap-table table))))

(define table-raw?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_raw"
			    #:return-type int
			    #:arg-types '(*)))

(define (raw? table)
  (= 1 (table-raw?-ffi (unwrap-table table))))

(define table-tree?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_is_tree"
			    #:return-type int
			    #:arg-types '(*)))

(define (tree? table)
  (= 1 (table-tree?-ffi (unwrap-table table))))

(define table-colored?-ffi
  (foreign-library-function libsmartcols
			    "scols_table_colors_wanted"
			    #:return-type int
			    #:arg-types '(*)))

(define (colored? table)
  (= 1 (table-colored?-ffi table)))

(define table-enable-colors-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_colors"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-colored! table enabled)
  (table-enable-colors-ffi (unwrap-table table) (if enabled 1 0)))

(define table-enabled-export-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_export"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-export! table enabled)
  (table-enabled-export-ffi (unwrap-table table) (if enabled 1 0)))

(define table-enabled-ascii-ffi
  (foreign-library-function libsmartcols
			    "scols_table_enable_ascii"
			    #:return-type int
			    #:arg-types (list '* int)))

(define (set-ascii! table enabled)
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
  (wrap-line
   (table-new-line-ffi (unwrap-table table)
		       %null-pointer)))

(define (new-line-child! table parent-line)
  (wrap-line
   (table-new-line-ffi (unwrap-table table)
		       (unwrap-line parent-line))))

(define (add-line! table line)
  (table-add-line-ffi (unwrap-table table) (unwrap-line line)))

(define remove-line-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_line"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (remove-line! table line)
  (remove-line-ffi (unwrap-table table)
		   (unwrap-line line)))

(define remove-lines-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_lines"
			    #:return-type int
			    #:arg-types '(*)))

(define (remove-lines! table)
  (remove-lines-ffi (unwrap-table table)))

(define get-table-column-ffi
  (foreign-library-function libsmartcols
			    "scols_table_get_column"
			    #:return-type '*
			    #:arg-types (list '* size_t)))

(define (get-column table nth)
  (wrap-column (get-table-column-ffi (unwrap-table table) nth)))

(define make-table-column-ffi
  (foreign-library-function libsmartcols
			    "scols_table_new_column"
			    #:return-type '*
			    #:arg-types (list '* '* double int)))

(define (new-column! table name width flags) 
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
  (remove-column-ffi (unwrap-table table)
		     (unwrap-column column)))


(define remove-columns-ffi
  (foreign-library-function libsmartcols
			    "scols_table_remove_columns"
			    #:return-type int
			    #:arg-types '(*)))

(define (remove-columns! table)
  (remove-columns-ffi (unwrap-table table)))

;;; column manipulation
(define make-column-ffi
  (foreign-library-function libsmartcols
			    "scols_new_column"
			    #:return-type '*
			    #:arg-types '()))


(define (make-column) (wrap-column (make-column-ffi)))


;;; line manipulation

(define make-line-ffi
  (foreign-library-function libsmartcols
			    "scols_new_line"
			    #:return-type '*
			    #:arg-types '()))

(define make-line (wrap-line (make-line-ffi)))

(define line-color-ffi
  (foreign-library-function libsmartcols
			    "scols_line_get_color"
			    #:return-type '*
			    #:arg-types '(*)))

(define (color line)
  (pointer->string (line-color-ffi (unwrap-line line))))

(define line-set-color-ffi
  (foreign-library-function libsmartcols
			    "scols_line_set_color"
			    #:return-type int
			    #:arg-types '(* *)))

(define (set-color! line color)
  (line-set-color-ffi (unwrap-line line) (string->pointer color "ascii")))

(define line-parent-ffi
  (foreign-library-function libsmartcols
			    "scols_line_get_parent"
			    #:return-type '*
			    #:arg-types '(*)))

(define (line-parent line)
  (wrap-line (line-parent-ffi (unwrap-line line))))

(define line-leaf-ffi
  (foreign-library-function libsmartcols
			    "scols_line_has_children"
			    #:return-type int
			    #:arg-types '(*)))

(define (leaf? line)
  (= 0 (line-leaf-ffi (unwrap-line line))))

(define remove-line-child-ffi
  (foreign-library-function libsmartcols
			    "scols_line_remove_child"
			    #:return-type int
			    #:arg-types (list '* '*)))

(define (remove-child! parent-line child-line)
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
  (with-output-to-string 
    (λ ()
      (let [(previous (table-get-stream-ffi (unwrap-table table)))] ;TODO(edoput) replace with dynamic-wind
	(table-set-stream-ffi (unwrap-table table) (port->fdes (current-output-port)))	
	(print-table-ffi (unwrap-table table))
	(table-set-stream-ffi (unwrap-table table) (previous))))))
