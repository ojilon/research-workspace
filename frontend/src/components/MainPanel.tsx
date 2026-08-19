import { useEffect, useState } from "react"
import { topics } from "../data/topics"
import SectionList from "./SectionList"
import SectionContent from "./SectionContent"

function MainPanel({ selectedTopic }) {

  const topic = topics.find((topic) => topic.id === selectedTopic)
  const [selectedSection, setSelectedSection] = useState(topic?.sections[0])

  useEffect(() => {
    setSelectedSection(topic?.sections[0])
  }, [selectedTopic])

  return (
    <main>
      <h2>{topic?.name}</h2>
      <p>{topic?.description}</p>

      <SectionList 
        sections={topic?.sections}
        selectedSection={selectedSection}
        setSelectedSection={setSelectedSection}
      />

      <SectionContent section={selectedSection} />
    </main>
  )
}

export default MainPanel