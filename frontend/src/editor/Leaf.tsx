import { RenderLeafProps } from "slate-react"

export function Leaf(props: RenderLeafProps) {
  const { leaf, attributes } = props

  let children = props.children

  if (leaf.bold) {
    children = <strong>{children}</strong>
  }

  if (leaf.italic) {
    children = <em>{children}</em>
  }

  if (leaf.underline) {
    children = <u>{children}</u>
  }

  return (
    <span {...attributes}>
      {children}
    </span>
  )
}