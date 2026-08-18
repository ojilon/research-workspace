const topics = [
    {
        id:"groewth",
        name: "Growth",
    },
    {
        id: "water-relations",
        name: "Water Relations",
    },
    {
        id:"photosynthesis",
        name:"Photosynthesis",
    },
]

function Sidebar() {
  return (
    <aside>
      <h2>Plant physiology</h2>

      <ul>
        {topics.map((topic) => (
            <li key={topic.id}>{topic.name}</li>
        ))}
      </ul>
    </aside>
  )
}

export default Sidebar