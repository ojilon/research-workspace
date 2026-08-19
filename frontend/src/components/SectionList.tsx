import type { Section } from "../types";

type SectionListProps = {
  sections: Section[];
  selectedSection: Section | undefined;
  setSelectedSection: (section: Section) => void;
};

/**
 * Simple vertical list of sections for the current document.
 * Clicking a section updates the content pane below.
 */
function SectionList({
  sections,
  selectedSection,
  setSelectedSection,
}: SectionListProps) {
  if (!sections || sections.length === 0) {
    return <p className="text-sm text-[var(--muted)]">No sections</p>;
  }

  return (
    <ul className="flex flex-col gap-1 mb-4">
      {sections.map((section) => {
        const isActive = selectedSection?.id === section.id;
        return (
          <li key={section.id}>
            <button
              type="button"
              onClick={() => setSelectedSection(section)}
              className={
                "w-full text-left px-3 py-1.5 rounded-md text-sm transition-colors " +
                (isActive
                  ? "bg-[var(--accent-muted)] text-[var(--accent)] font-medium"
                  : "text-[var(--text)] hover:bg-[var(--hover)]")
              }
            >
              {section.title}
            </button>
          </li>
        );
      })}
    </ul>
  );
}

export default SectionList;
