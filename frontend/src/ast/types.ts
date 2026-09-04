// src/ast/types.ts

export interface DocumentNode {
  id: string
  type: "document"
  children: BlockNode[]
}

export type BlockNode =
  | ParagraphNode
  | HeadingNode

export interface ParagraphNode {
  id: string
  type: "paragraph"
  children: TextNode[]
}

export interface HeadingNode {
  id: string
  type: "heading"
  level: 1 | 2 | 3 | 4 | 5 | 6
  children: TextNode[]
}

export interface TextNode {
  text: string

  bold?: boolean
  italic?: boolean
  underline?: boolean
}