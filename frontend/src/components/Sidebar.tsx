import { topics } from "../data/topics"

function Sidebar({selectedTopic, setSelectedTopic}) {
  return (
    <aside>
      <h2>Plant Physiology</h2>

      <ul>
        {topics.map((topic) => (
          <li 
            key={topic.id} 
            onClick={() => setSelectedTopic(topic.id)}
            style={{
                fontWeight: selectedTopic === topic.id ? "bold": "normal",
            }}
            >
            {topic.name}</li>
        ))}
      </ul>
    </aside>
  )
}

export default Sidebar