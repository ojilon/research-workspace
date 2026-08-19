type Section = {
  id: string
  title: string
  content: string
}

type SectionListProps = {
  sections: Section[]
  selectedSection: Section
  setSelectedSection: (section: Section) => void
}

function SectionList({sections, selectedSection,setSelectedSection,}: SectionListProps) {
  return (
    <ul>
      {sections.map((section) => (
        <li
          key={section.id}
          onClick={() => setSelectedSection(section)}
          style={{fontWeight:selectedSection.id === section.id ? "bold" : "normal",}}> {section.title}
        </li>
      ))}
    </ul>
  )
}

export default SectionList