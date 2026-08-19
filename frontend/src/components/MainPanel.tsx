import { useEffect, useState } from "react";
import { topics } from "../data/topics";
import type { Section } from "../types";
import SectionList from "./SectionList";
import SectionContent from "./SectionContent";

type MainPanelProps = {
  selectedTopicId: string;
};

/**
 * Centre content for a document tab.
 * Shows topic title, description, section list, and the active section body.
 */
function MainPanel({ selectedTopicId }: MainPanelProps) {
  const topic = topics.find((t) => t.id === selectedTopicId);
  const [selectedSection, setSelectedSection] = useState<
    Section | undefined
  >(topic?.sections[0]);

  // When the user switches topic, reset to the first section of the new topic.
  useEffect(() => {
    setSelectedSection(topic?.sections[0]);
  }, [selectedTopicId, topic]);

  if (!topic) {
    return (
      <div className="p-6 text-[var(--muted)]">
        No topic selected or topic not found.
      </div>
    );
  }

  return (
    <div className="h-full overflow-auto p-5">
      <header className="mb-5">
        <h2 className="text-xl font-semibold text-[var(--text-h)]">
          {topic.name}
        </h2>
        <p className="mt-1 text-sm text-[var(--muted)]">{topic.description}</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-[220px_1fr] gap-6">
        <SectionList
          sections={topic.sections}
          selectedSection={selectedSection}
          setSelectedSection={setSelectedSection}
        />
        <SectionContent section={selectedSection} />
      </div>
    </div>
  );
}

export default MainPanel;
