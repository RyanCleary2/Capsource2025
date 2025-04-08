
let userRole = null;

function handleRoleChange() {
  const roleSelect = document.getElementById('roleSelect');
  if (!roleSelect) return;

  roleSelect.addEventListener('change', function () {
    userRole = this.value;
    const container = document.getElementById('messages');

    const botMessages = container.querySelectorAll('.message.bot:not(:first-child), .feedback-buttons');
    botMessages.forEach(msg => msg.remove());

    const intro = document.createElement('div');
    intro.classList.add('message', 'bot');
    intro.textContent = {
      student: "Welcome student! CapSource helps you discover real-world projects, mentorships, and career exploration opportunities.",
      industry: "Welcome industry partner! CapSource helps you connect with top student talent through real-world projects and collaborations.",
      academic: "Welcome educator! CapSource helps integrate experiential learning into your curriculum through projects with real companies."
    }[userRole];
    container.appendChild(intro);

    const followup = document.createElement('div');
    followup.classList.add('message', 'bot');
    followup.textContent = {
      student: 'What year are you in and what is your major?',
      industry: 'What is your role and what type of student collaboration are you seeking?',
      academic: 'What subject do you teach and are you exploring CapSource for a specific course or program?'
    }[userRole];
    container.appendChild(followup);
  });
}

document.getElementById('sendButton').addEventListener('click', async function () {
  const input = document.getElementById('chatInput');
  const message = input.value.trim();
  if (!message) return;

  addMessage(message, 'user');
  input.value = '';
  showTyping();

  const res = await fetch('http://localhost:5000/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, sessionId: 'user1', role: userRole })
  });

  removeTyping();
  const data = await res.json();
  addMessage(data.response, 'bot');
});

function addMessage(text, sender = 'bot') {
  const msg = document.createElement('div');
  msg.className = `message ${sender}`;
  msg.textContent = text;
  document.getElementById('messages').appendChild(msg);

  if (sender === 'bot') {
    const feedback = document.createElement('div');
    feedback.className = 'feedback-buttons';
    feedback.innerHTML = `
      <button onclick="sendFeedback(\`${text.replace(/`/g, '\`')}\`, 'thumbs_up')">👍</button>
      <button onclick="sendFeedback(\`${text.replace(/`/g, '\`')}\`, 'thumbs_down')">👎</button>
    `;
    document.getElementById('messages').appendChild(feedback);
  }
}

function showTyping() {
  const typing = document.createElement('div');
  typing.className = 'message bot typing';
  typing.id = 'typing-indicator';
  typing.textContent = 'CapChat is typing...';
  document.getElementById('messages').appendChild(typing);
}

function removeTyping() {
  const typing = document.getElementById('typing-indicator');
  if (typing) typing.remove();
}

async function sendFeedback(message, feedbackType) {
  await fetch('http://localhost:5000/feedback', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message,
      feedback: feedbackType,
      role: userRole,
      sessionId: 'user1'
    })
  });
}

document.getElementById('resetBtn').addEventListener('click', () => {
  const container = document.getElementById('messages');
  container.innerHTML = '';

  const intro = document.createElement('div');
  intro.className = 'message bot';
  intro.innerHTML = 'Tell us more about yourself. Which option best describes you? <select class="dropdown" id="roleSelect"><option value="" selected disabled>Select</option><option value="student">Student/Grad</option><option value="industry">Industry</option><option value="academic">Academic</option></select>';
  container.appendChild(intro);

  handleRoleChange(); // 👈 rebind dropdown listener
});

document.addEventListener('DOMContentLoaded', () => {
  handleRoleChange(); // 👈 bind on initial load
});
