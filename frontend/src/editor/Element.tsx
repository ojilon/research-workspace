import { RenderElementProps } from "slate-react"

export function Element(props: RenderElementProps) {
  const { element, attributes, children } = props

  switch (element.type) {
    case "heading":
      return <h1 {...attributes}>{children}</h1>

    case "paragraph":
      return <p {...attributes}>{children}</p>

    default:
      return <p {...attributes}>{children}</p>
  }
}