import type { Section } from "../types";

type SectionContentProps = {
  section: Section | undefined;
};

/**
 * Renders the body of the currently selected section.
 * Supports paragraph blocks for now; easy to extend later.
 */
function SectionContent({ section }: SectionContentProps) {
  if (!section) {
    return (
      <div className="text-sm text-[var(--muted)] italic">
        Select a section to read its content.
      </div>
    );
  }

  return (
    <section className="prose-like">
      <h3 className="text-lg font-semibold mb-3 text-[var(--text-h)]">
        {section.title}
      </h3>

      {section.content.map((block, index) => {
        if (block.type === "paragraph") {
          return (
            <p
              key={index}
              className="mb-3 leading-relaxed text-[var(--text)]"
            >
              {block.text}
            </p>
          );
        }
        return null;
      })}
    </section>
  );
}

export default SectionContent;
