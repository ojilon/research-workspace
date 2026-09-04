// frontend/src/slate.d.ts
// Augment Slate's types so custom properties (type, bold, italic, etc.) are recognized by TypeScript.

import { BaseEditor } from "slate"
import { ReactEditor } from "slate-react"

export type CustomText = {
  text: string
  bold?: boolean
  italic?: boolean
  underline?: boolean
}

export type ParagraphElement = {
  id: string
  type: "paragraph"
  children: CustomText[]
}

export type HeadingElement = {
  id: string
  type: "heading"
  level: 1 | 2 | 3 | 4 | 5 | 6
  children: CustomText[]
}

export type CustomElement = ParagraphElement | HeadingElement

declare module "slate" {
  interface CustomTypes {
    Editor: BaseEditor & ReactEditor
    Element: CustomElement
    Text: CustomText
  }
}
