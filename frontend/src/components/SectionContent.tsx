type ContentBlock = {
  type: "paragraph"
  text: string
}

type Section = {
  id: string
  title: string
  content: ContentBlock[]
}

type SectionContentProps = {
  section: Section
}

function SectionContent({ section }: SectionContentProps) {
  return (
    <section>
      <h3>{section.title}</h3>

      {section.content.map((block, index) => {
        switch (block.type) {
          case "paragraph":
            return <p key={index}>{block.text}</p>

          default:
            return null
        }
      })}
    </section>
  )
}

export default SectionContent