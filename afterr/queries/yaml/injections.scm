;extends

; query
;; my injection
; (block_mapping_pair
;   key: (flow_node (plain_scalar (string_scalar))) @key
;   value: (flow_node) @injection.content
;   (#eq? @key "signature")
;   (#set! injection.language "sql")
; )
;
; (
;  (string_scalar)@injection.content
;  (#set! injection.language "sql")
; )
;
; (
;  (block_mapping_pair
;    value: (flow_node)@injection.content
;    (#set! injection.language "sql")
;  )
; )

; ((block_mapping_pair key:
;   (flow_node) @key
;    value:
;    (flow_node
;      (plain_scalar
;        (string_scalar)
;        @injection.content
;        (#eq? @key "signature")
;        (#set! injection.language "sql")))))

; (
;  (block_mapping_pair
;    key: (flow_node) @key
;    value: (flow_node
;              (plain_scalar
;                (string_scalar) @injection.content
;              )
;    )
;  )
;  (#eq? @key "signature")
;  (#set! injection.language "sql" @injection.content)
; )

; (
;  (block_mapping_pair
;    key: (flow_node) @key
;    value: (flow_node
;              [
;                (plain_scalar
;                (string_scalar)
;                @injection.content)
;                (single_quote_scalar)
;                (double_quote_scalar)
;                (block_scalar)
;              ] 
;    )
;  )
;  (#eq? @key "signature")
;  (#set! injection.language "sql" @injection.content)
; )


(
 (block_mapping_pair
   key: (flow_node) @key
   value: [
           (flow_node [
            (plain_scalar
             (string_scalar)@injection.content)
            (single_quote_scalar)@injection.content
            (double_quote_scalar) @injection.content
            ])
           (block_node
             (block_scalar)
             @injection.content)
          ])
 (#eq? @key "signature")
 (#set! injection.language "regex" @injection.content)
)
