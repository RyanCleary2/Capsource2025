// Skill Progression Roadmap Modal JavaScript
// Handles fetching and displaying skill roadmap data

window.openRoadmapModal = function(skillId) {
  const modal = document.getElementById('roadmap-modal');
  const loading = document.getElementById('roadmap-loading');
  const container = document.getElementById('roadmap-container');
  const emptyState = document.getElementById('roadmap-empty');

  // Show modal and loading state
  modal.style.display = 'block';
  loading.style.display = 'flex';
  container.style.display = 'none';
  emptyState.style.display = 'none';

  // Fetch roadmap data
  fetch(`/skills/${skillId}/roadmap`)
    .then(response => {
      if (!response.ok) {
        throw new Error('Failed to load roadmap');
      }
      return response.json();
    })
    .then(data => {
      renderRoadmap(data);
      loading.style.display = 'none';

      // Check if there's any content
      const hasContent = data.prerequisites.length > 0 ||
                        data.progressions.length > 0 ||
                        data.related.length > 0;

      if (hasContent) {
        container.style.display = 'block';
      } else {
        emptyState.style.display = 'block';
      }
    })
    .catch(error => {
      console.error('Error loading roadmap:', error);
      loading.innerHTML = `
        <div style="text-align: center; color: #E53E3E;">
          <p>⚠️ Failed to load roadmap</p>
          <p style="font-size: 13px;">${error.message}</p>
        </div>
      `;
    });
}

window.closeRoadmapModal = function() {
  const modal = document.getElementById('roadmap-modal');
  modal.style.display = 'none';
};

function renderRoadmap(data) {
  const { current, prerequisites, progressions, related } = data;

  // Update modal title
  document.getElementById('roadmap-title').textContent =
    `Progression Roadmap: ${current.name}`;

  // Render current skill
  renderCurrentSkill(current);

  // Render prerequisites
  renderSection('prerequisites', prerequisites);

  // Render progressions
  renderSection('progressions', progressions);

  // Render related skills
  renderRelatedSkills(related);
}

function renderCurrentSkill(skill) {
  const badge = document.getElementById('current-skill-badge');
  const category = getCategory(skill.category);

  badge.innerHTML = `
    <div class="skill-badge-name">${skill.name}</div>
    <div class="skill-badge-level">${skill.skill_level || 'Intermediate'}</div>
    ${skill.description ? `<p style="margin-top: 12px; font-size: 13px; line-height: 1.5; opacity: 0.95;">${skill.description}</p>` : ''}
    <div style="margin-top: 12px; font-size: 12px;">
      <span style="background: rgba(255,255,255,0.2); padding: 4px 10px; border-radius: 10px;">
        ${category.name}
      </span>
    </div>
  `;
}

function renderSection(sectionType, skills) {
  const section = document.getElementById(`${sectionType}-section`);
  const path = document.getElementById(`${sectionType}-path`);

  if (skills.length === 0) {
    section.style.display = 'none';
    return;
  }

  section.style.display = 'block';
  path.innerHTML = '';

  skills.forEach((skill, index) => {
    if (index > 0) {
      path.innerHTML += '<div class="roadmap-arrow"></div>';
    }
    path.innerHTML += createSkillBadge(skill, true);
  });
}

function renderRelatedSkills(skills) {
  const section = document.getElementById('related-section');
  const grid = document.getElementById('related-grid');

  if (skills.length === 0) {
    section.style.display = 'none';
    return;
  }

  section.style.display = 'block';
  grid.innerHTML = '';

  skills.forEach(skill => {
    grid.innerHTML += createSkillBadge(skill, false);
  });
}

function createSkillBadge(skill, showEffort = true) {
  const category = getCategory(skill.category);

  return `
    <div class="skill-badge" onclick="openRoadmapModal(${skill.id})" data-skill-id="${skill.id}">
      <div class="skill-badge-name">${skill.name}</div>
      <div class="skill-badge-level">${skill.skill_level || 'Intermediate'}</div>
      ${showEffort && skill.effort_weeks ?
        `<div class="skill-badge-effort">${skill.effort_weeks} weeks</div>` : ''}
      ${skill.similarity_score ?
        `<div class="skill-badge-similarity">${skill.similarity_score}% match</div>` : ''}
    </div>
  `;
}

function getCategory(categoryId) {
  const categories = {
    'programming': { name: 'Programming Languages', color: '#9F7AEA' },
    'data-analytics': { name: 'Data & Analytics', color: '#4FD1C7' },
    'engineering': { name: 'Engineering & CAD', color: '#F6AD55' },
    'web-dev': { name: 'Web Development', color: '#667EEA' },
    'devops': { name: 'DevOps & Tools', color: '#FC8181' },
    'business': { name: 'Business Strategy', color: '#38B2AC' },
    'marketing': { name: 'Marketing & Sales', color: '#ED8936' },
    'communication': { name: 'Communication & Soft Skills', color: '#68D391' },
    'project-mgmt': { name: 'Project Management', color: '#9F7AEA' },
    'research': { name: 'Research & Analysis', color: '#4299E1' },
    'other': { name: 'Other', color: '#A0AEC0' }
  };

  return categories[categoryId] || categories['other'];
}

// Close modal when clicking outside
window.onclick = function(event) {
  const modal = document.getElementById('roadmap-modal');
  if (event.target === modal) {
    closeRoadmapModal();
  }
}

// Close modal with Escape key
document.addEventListener('keydown', function(event) {
  if (event.key === 'Escape') {
    const modal = document.getElementById('roadmap-modal');
    if (modal.style.display === 'block') {
      closeRoadmapModal();
    }
  }
});