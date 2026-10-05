// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}

// ---------------- STATE & DATA LAYER ----------------
const DAY_MS = 24 * 60 * 60 * 1000;
const BOTS = ['alice', 'bob', 'carol', 'dave', 'erin'];
const BOT_DATA = {
  alice: { bio: 'Coffee, trails & film cameras ☕🌲', isPrivate: false, color: '#7c5cff' },
  bob: { bio: 'Building things slowly. Minimalist 🛠️', isPrivate: false, color: '#ff5c8a' },
  carol: { bio: 'Books > feeds. Living quietly 📖', isPrivate: false, color: '#22c3a6' },
  dave: { bio: 'Offline most of the day 🚲', isPrivate: false, color: '#ffa63d' },
  erin: { bio: 'Private account. Direct connections only 🔒', isPrivate: true, color: '#3d8bff' }
};

const BOT_STORIES = {
  alice: ['Sunrise hike above the clouds 🌄', 'Morning espresso ritual ☕'],
  bob: ['Shipped a new minimal woodworking project! 🪵'],
  carol: ['Reading chapter 4. Highly recommend 📚'],
  dave: ['Campfire vibes tonight 🔥'],
  erin: ['Private circle update ✨']
};

const BOT_REPLIES = [
  'Haha that is awesome!',
  'Love that! Keep it up 🙌',
  'Tell me more about it!',
  'Sounds great, let us catch up later.',
  'Same here, so good to disconnect from toxic feeds 🌿',
  'Definitely agree with you!'
];

class AppStore {
  constructor() {
    this.users = {};
    this.following = {};
    this.requests = [];
    this.stories = [];
    this.messages = [];
    this.creds = {};
    this.me = null;
    this.igFollowers = [];
    this.igFollowing = [];
    this.igDone = [];
    this.load();
  }

  load() {
    try {
      const raw = localStorage.getItem('unscroll_db');
      if (raw) {
        const d = JSON.parse(raw);
        this.users = d.users || {};
        this.following = d.following || {};
        this.requests = d.requests || [];
        this.stories = d.stories || [];
        this.messages = d.messages || [];
        this.creds = d.creds || {};
        this.me = d.me || null;
      } else {
        this.seed();
      }

      this.igFollowers = JSON.parse(localStorage.getItem('ig_followers') || '[]');
      this.igFollowing = JSON.parse(localStorage.getItem('ig_following') || '[]');
      this.igDone = JSON.parse(localStorage.getItem('ig_done') || '[]');

      this.refreshBotStories();
      this.save();
    } catch (e) {
      this.seed();
    }
  }

  seed() {
    this.users = {};
    for (const b of BOTS) {
      this.users[b] = { id: b, ...BOT_DATA[b] };
    }
    this.following = {
      alice: ['bob', 'carol'],
      bob: ['alice'],
      carol: ['alice', 'dave'],
      dave: [],
      erin: ['alice']
    };
    this.requests = [];
    this.stories = [];
    this.messages = [];
    this.creds = {};
    this.me = null;
  }

  refreshBotStories() {
    const now = Date.now();
    // Remove expired stories
    this.stories = this.stories.filter(s => now - s.createdAt < DAY_MS);

    // Ensure bots have fresh active stories
    for (const b of BOTS) {
      const hasActive = this.stories.some(s => s.authorId === b && now - s.createdAt < DAY_MS);
      if (!hasActive) {
        const caps = BOT_STORIES[b] || ['Moment'];
        caps.forEach((cap, i) => {
          this.stories.push({
            id: 's_' + b + '_' + i + '_' + now,
            authorId: b,
            caption: cap,
            image: null,
            color: this.users[b]?.color || '#7c5cff',
            createdAt: now - (i + 1) * 3600000,
            viewers: []
          });
        });
      }
    }
  }

  save() {
    localStorage.setItem('unscroll_db', JSON.stringify({
      users: this.users,
      following: this.following,
      requests: this.requests,
      stories: this.stories,
      messages: this.messages,
      creds: this.creds,
      me: this.me
    }));
  }

  saveIg() {
    localStorage.setItem('ig_followers', JSON.stringify(this.igFollowers));
    localStorage.setItem('ig_following', JSON.stringify(this.igFollowing));
    localStorage.setItem('ig_done', JSON.stringify(this.igDone));
  }

  signup(username, password) {
    const u = username.trim().toLowerCase();
    if (!/^[a-z0-9_.]{3,20}$/.test(u)) {
      return 'Username must be 3-20 characters (letters, numbers, _ or .)';
    }
    if (password.length < 4) return 'Password must be at least 4 characters';
    if (this.users[u]) return 'Username is already taken';

    this.users[u] = {
      id: u,
      bio: 'New here on Unscroll ✨',
      isPrivate: false,
      color: '#7c5cff'
    };
    this.creds[u] = password;
    this.following[u] = ['alice', 'bob', 'carol', 'dave'];
    if (!this.following['alice']) this.following['alice'] = [];
    this.following['alice'].push(u);
    if (!this.following['carol']) this.following['carol'] = [];
    this.following['carol'].push(u);
    this.requests.push(['erin', u]);

    this.messages.push({
      id: 'm_' + Date.now(),
      from: 'alice',
      to: u,
      text: 'Welcome to Unscroll! No endless feeds, no ads. Just authentic connections.',
      time: Date.now()
    });

    this.me = u;
    this.save();
    return null;
  }

  login(username, password) {
    const u = username.trim().toLowerCase();
    if (!this.creds[u] || this.creds[u] !== password) {
      return 'Incorrect username or password';
    }
    this.me = u;
    this.save();
    return null;
  }

  logout() {
    this.me = null;
    this.save();
  }

  isFollowing(id) {
    return (this.following[this.me] || []).includes(id);
  }

  followsMe(id) {
    return (this.following[id] || []).includes(this.me);
  }

  hasRequested(id) {
    return this.requests.some(r => r[0] === this.me && r[1] === id);
  }

  getFollowers(id = this.me) {
    return Object.keys(this.following).filter(k => (this.following[k] || []).includes(id));
  }

  follow(id) {
    if (this.isFollowing(id) || this.hasRequested(id)) return;
    const target = this.users[id];
    if (target?.isPrivate) {
      this.requests.push([this.me, id]);
      if (BOTS.includes(id)) {
        setTimeout(() => {
          this.requests = this.requests.filter(r => !(r[0] === this.me && r[1] === id));
          if (!this.following[this.me]) this.following[this.me] = [];
          this.following[this.me].push(id);
          this.save();
          renderAll();
        }, 2000);
      }
    } else {
      if (!this.following[this.me]) this.following[this.me] = [];
      this.following[this.me].push(id);
      if (BOTS.includes(id) && Math.random() > 0.3) {
        setTimeout(() => {
          if (!this.following[id]) this.following[id] = [];
          if (!this.following[id].includes(this.me)) {
            this.following[id].push(this.me);
            this.save();
            renderAll();
          }
        }, 1200);
      }
    }
    this.save();
  }

  unfollow(id) {
    if (this.following[this.me]) {
      this.following[this.me] = this.following[this.me].filter(u => u !== id);
      this.save();
    }
  }

  cancelRequest(id) {
    this.requests = this.requests.filter(r => !(r[0] === this.me && r[1] === id));
    this.save();
  }

  getIncomingRequests() {
    return this.requests.filter(r => r[1] === this.me).map(r => r[0]);
  }

  acceptRequest(from) {
    this.requests = this.requests.filter(r => !(r[0] === from && r[1] === this.me));
    if (!this.following[from]) this.following[from] = [];
    if (!this.following[from].includes(this.me)) this.following[from].push(this.me);
    this.save();
  }

  deleteRequest(from) {
    this.requests = this.requests.filter(r => !(r[0] === from && r[1] === this.me));
    this.save();
  }

  getNotFollowingBack() {
    const myFollowing = this.following[this.me] || [];
    return myFollowing.filter(id => !this.followsMe(id));
  }

  // Stories
  getActiveStories(authorId) {
    const now = Date.now();
    return this.stories
      .filter(s => s.authorId === authorId && now - s.createdAt < DAY_MS)
      .sort((a, b) => a.createdAt - b.createdAt);
  }

  getFollowingStoryAuthors() {
    const followed = this.following[this.me] || [];
    return followed.filter(id => this.getActiveStories(id).length > 0);
  }

  hasUnseenStories(authorId) {
    const stories = this.getActiveStories(authorId);
    return stories.some(s => !s.viewers.includes(this.me));
  }

  addStory(caption, imageBase64) {
    const s = {
      id: 's_' + Date.now(),
      authorId: this.me,
      caption: caption || '',
      image: imageBase64 || null,
      color: this.users[this.me]?.color || '#7c5cff',
      createdAt: Date.now(),
      viewers: []
    };
    this.stories.push(s);
    this.save();

    // Bots simulate viewing after a few seconds
    setTimeout(() => {
      for (const b of BOTS) {
        if (!s.viewers.includes(b)) s.viewers.push(b);
      }
      this.save();
    }, 4000);
  }

  markStoryViewed(storyId) {
    const s = this.stories.find(x => x.id === storyId);
    if (s && s.authorId !== this.me && !s.viewers.includes(this.me)) {
      s.viewers.push(this.me);
      this.save();
    }
  }

  // Messaging
  getConversations() {
    const peers = new Set();
    this.messages.forEach(m => {
      if (m.from === this.me) peers.add(m.to);
      if (m.to === this.me) peers.add(m.from);
    });
    return Array.from(peers).sort((a, b) => {
      const lastA = this.getThread(a).slice(-1)[0]?.time || 0;
      const lastB = this.getThread(b).slice(-1)[0]?.time || 0;
      return lastB - lastA;
    });
  }

  getThread(peer) {
    return this.messages
      .filter(m => (m.from === this.me && m.to === peer) || (m.from === peer && m.to === this.me))
      .sort((a, b) => a.time - b.time);
  }

  sendMessage(to, { text, image, video, storyRef }) {
    const msg = {
      id: 'm_' + Date.now(),
      from: this.me,
      to,
      text: text || '',
      image: image || null,
      video: video || null,
      storyRef: storyRef || null,
      time: Date.now()
    };
    this.messages.push(msg);
    this.save();

    if (BOTS.includes(to)) {
      setTimeout(() => {
        const reply = {
          id: 'm_' + Date.now(),
          from: to,
          to: this.me,
          text: BOT_REPLIES[Math.floor(Math.random() * BOT_REPLIES.length)],
          time: Date.now()
        };
        this.messages.push(reply);
        this.save();
        renderAll();
        if (currentChatPeer === to) renderChatMessages();
      }, 1400);
    }
  }
}

const store = new AppStore();

// ---------------- UI ROUTING & NAVIGATION ----------------
const authScreen = document.getElementById('auth-screen');
const mainScreen = document.getElementById('main-screen');
const authForm = document.getElementById('auth-form');
const authUsername = document.getElementById('auth-username');
const authPassword = document.getElementById('auth-password');
const authError = document.getElementById('auth-error');
const authSubmitBtn = document.getElementById('auth-submit-btn');
const authToggleBtn = document.getElementById('auth-toggle-btn');
let isSignUpMode = true;

function checkAuth() {
  if (store.me && store.users[store.me]) {
    authScreen.classList.remove('active');
    mainScreen.classList.add('active');
    renderAll();
  } else {
    mainScreen.classList.remove('active');
    authScreen.classList.add('active');
  }
}

authToggleBtn.addEventListener('click', () => {
  isSignUpMode = !isSignUpMode;
  authError.textContent = '';
  authSubmitBtn.textContent = isSignUpMode ? 'Create account' : 'Log in';
  authToggleBtn.textContent = isSignUpMode ? 'Have an account? Log in' : 'New here? Create account';
});

authForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const u = authUsername.value.trim();
  const p = authPassword.value;
  const err = isSignUpMode ? store.signup(u, p) : store.login(u, p);
  if (err) {
    authError.textContent = err;
  } else {
    authError.textContent = '';
    authUsername.value = '';
    authPassword.value = '';
    checkAuth();
  }
});

// Bottom Tabs Navigation
const navItems = document.querySelectorAll('.bottom-nav .nav-item');
const tabPanes = document.querySelectorAll('.tab-viewport .tab-pane');
const headerTitle = document.getElementById('header-title');

navItems.forEach(item => {
  item.addEventListener('click', () => {
    const tabName = item.dataset.tab;
    navItems.forEach(n => n.classList.remove('active'));
    tabPanes.forEach(p => p.classList.remove('active'));

    item.classList.add('active');
    document.getElementById('tab-' + tabName).classList.add('active');

    const titles = { stories: 'Unscroll', messages: 'Messages', people: 'People', profile: 'Profile' };
    headerTitle.textContent = titles[tabName] || 'Unscroll';
  });
});

// ---------------- STORIES LOGIC ----------------
const storiesFeed = document.getElementById('stories-feed');
const myStoryCard = document.getElementById('my-story-card');
const myStoryAvatar = document.getElementById('my-story-avatar');
const myStoryStatus = document.getElementById('my-story-status');
const myStoryRing = document.getElementById('my-story-ring');
const btnAddStoryInline = document.getElementById('btn-add-story-inline');
const headerActionBtn = document.getElementById('header-action-btn');

function renderStories() {
  if (!store.me) return;
  const myStories = store.getActiveStories(store.me);
  myStoryAvatar.textContent = store.me[0].toUpperCase();
  myStoryAvatar.style.backgroundColor = store.users[store.me]?.color || '#7c5cff';

  if (myStories.length === 0) {
    myStoryStatus.textContent = 'Tap to share a moment';
    myStoryRing.className = 'avatar-ring';
  } else {
    myStoryStatus.textContent = `${myStories.length} active story · expires in 24h`;
    myStoryRing.className = 'avatar-ring unseen';
  }

  const authors = store.getFollowingStoryAuthors();
  storiesFeed.innerHTML = '';
  authors.forEach(authorId => {
    const user = store.users[authorId];
    const stories = store.getActiveStories(authorId);
    const unseen = store.hasUnseenStories(authorId);
    const lastStory = stories[stories.length - 1];
    const timeAgo = formatTimeAgo(lastStory.createdAt);

    const el = document.createElement('div');
    el.className = 'story-item';
    el.innerHTML = `
      <div class="avatar-ring ${unseen ? 'unseen' : 'seen'}">
        <div class="avatar" style="background-color: ${user.color || '#7c5cff'}">${authorId[0].toUpperCase()}</div>
      </div>
      <div class="story-item-info">
        <div class="story-item-name">${authorId}</div>
        <div class="story-item-status">${timeAgo} · ${stories.length} story</div>
      </div>
    `;
    el.addEventListener('click', () => openStoryViewer(authorId));
    storiesFeed.appendChild(el);
  });
}

myStoryCard.addEventListener('click', (e) => {
  if (e.target === btnAddStoryInline) {
    openComposeStory();
    return;
  }
  const myStories = store.getActiveStories(store.me);
  if (myStories.length > 0) {
    openStoryViewer(store.me);
  } else {
    openComposeStory();
  }
});
headerActionBtn.addEventListener('click', openComposeStory);

// Story Compose Modal
const modalComposeStory = document.getElementById('modal-compose-story');
const storyFileInput = document.getElementById('story-file-input');
const storyCaptionInput = document.getElementById('story-caption-input');
const storyPreviewImg = document.getElementById('story-preview-img');
const storyPreviewText = document.getElementById('story-preview-text');
const btnPostStory = document.getElementById('btn-post-story');
let currentStoryImageBase64 = null;

function openComposeStory() {
  currentStoryImageBase64 = null;
  storyPreviewImg.classList.add('hidden');
  storyPreviewImg.src = '';
  storyPreviewText.textContent = '';
  storyCaptionInput.value = '';
  modalComposeStory.classList.add('active');
}

storyFileInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (event) => {
    currentStoryImageBase64 = event.target.result;
    storyPreviewImg.src = currentStoryImageBase64;
    storyPreviewImg.classList.remove('hidden');
  };
  reader.readAsDataURL(file);
});

storyCaptionInput.addEventListener('input', () => {
  storyPreviewText.textContent = storyCaptionInput.value;
});

btnPostStory.addEventListener('click', () => {
  const caption = storyCaptionInput.value.trim();
  if (!currentStoryImageBase64 && !caption) {
    showToast('Please add a photo or write a caption');
    return;
  }
  store.addStory(caption, currentStoryImageBase64);
  modalComposeStory.classList.remove('active');
  showToast('Story shared! Expires in 24h 🌿');
  renderAll();
});

modalComposeStory.querySelector('.btn-close-modal').addEventListener('click', () => {
  modalComposeStory.classList.remove('active');
});

// Story Viewer Modal
const modalStoryViewer = document.getElementById('modal-story-viewer');
const storyProgressContainer = document.getElementById('story-progress-container');
const viewerAuthorAvatar = document.getElementById('viewer-author-avatar');
const viewerAuthorName = document.getElementById('viewer-author-name');
const viewerStoryTime = document.getElementById('viewer-story-time');
const viewerStoryImg = document.getElementById('viewer-story-img');
const viewerStoryBg = document.getElementById('viewer-story-bg');
const viewerStoryCaption = document.getElementById('viewer-story-caption');
const viewerOwnControls = document.getElementById('viewer-own-controls');
const viewerReplyControls = document.getElementById('viewer-reply-controls');
const viewerCountLabel = document.getElementById('viewer-count-label');
const viewerReplyInput = document.getElementById('viewer-reply-input');
const btnSendStoryReply = document.getElementById('btn-send-story-reply');
const storyTouchArea = document.getElementById('story-touch-area');

let viewingAuthor = null;
let viewerStoriesList = [];
let viewingStoryIndex = 0;
let storyTimer = null;
let storyTimerProgress = 0;

function openStoryViewer(authorId) {
  viewingAuthor = authorId;
  viewerStoriesList = store.getActiveStories(authorId);
  if (viewerStoriesList.length === 0) return;
  viewingStoryIndex = 0;
  modalStoryViewer.classList.add('active');
  showStoryItem(viewingStoryIndex);
}

function showStoryItem(index) {
  clearInterval(storyTimer);
  if (index < 0 || index >= viewerStoriesList.length) {
    closeStoryViewer();
    return;
  }
  viewingStoryIndex = index;
  const s = viewerStoriesList[index];
  store.markStoryViewed(s.id);

  // Author details
  viewerAuthorName.textContent = viewingAuthor;
  viewerAuthorAvatar.textContent = viewingAuthor[0].toUpperCase();
  viewerAuthorAvatar.style.backgroundColor = store.users[viewingAuthor]?.color || '#7c5cff';
  viewerStoryTime.textContent = formatTimeAgo(s.createdAt);

  // Media & Caption
  if (s.image) {
    viewerStoryImg.src = s.image;
    viewerStoryImg.classList.remove('hidden');
    viewerStoryBg.classList.add('hidden');
  } else {
    viewerStoryImg.classList.add('hidden');
    viewerStoryBg.classList.remove('hidden');
    viewerStoryBg.style.background = `linear-gradient(180deg, ${s.color || '#3d248b'} 0%, #000 100%)`;
  }
  viewerStoryCaption.textContent = s.caption || '';
  viewerStoryCaption.style.display = s.caption ? 'block' : 'none';

  // Bottom controls (Own vs. Peer)
  if (viewingAuthor === store.me) {
    viewerOwnControls.classList.remove('hidden');
    viewerReplyControls.classList.add('hidden');
    viewerCountLabel.textContent = `Seen by ${s.viewers.length}`;
  } else {
    viewerOwnControls.classList.add('hidden');
    viewerReplyControls.classList.remove('hidden');
    viewerReplyInput.placeholder = `Reply to ${viewingAuthor}...`;
  }

  // Progress Bars
  renderProgressBars();
  startStoryTimer();
  renderStories();
}

function renderProgressBars() {
  storyProgressContainer.innerHTML = '';
  viewerStoriesList.forEach((_, idx) => {
    const seg = document.createElement('div');
    seg.className = 'progress-segment' + (idx < viewingStoryIndex ? ' passed' : '');
    const fill = document.createElement('div');
    fill.className = 'progress-segment-fill';
    if (idx === viewingStoryIndex) {
      fill.id = 'current-progress-fill';
    }
    seg.appendChild(fill);
    storyProgressContainer.appendChild(seg);
  });
}

function startStoryTimer() {
  storyTimerProgress = 0;
  const fill = document.getElementById('current-progress-fill');
  const duration = 5000;
  const interval = 50;

  storyTimer = setInterval(() => {
    storyTimerProgress += interval;
    if (fill) fill.style.width = Math.min(100, (storyTimerProgress / duration) * 100) + '%';
    if (storyTimerProgress >= duration) {
      clearInterval(storyTimer);
      showStoryItem(viewingStoryIndex + 1);
    }
  }, interval);
}

function closeStoryViewer() {
  clearInterval(storyTimer);
  modalStoryViewer.classList.remove('active');
  viewingAuthor = null;
}

modalStoryViewer.querySelector('.btn-close-story').addEventListener('click', closeStoryViewer);

// Touch navigation (left 35% = previous, right 65% = next)
storyTouchArea.addEventListener('click', (e) => {
  const rect = storyTouchArea.getBoundingClientRect();
  const x = e.clientX - rect.left;
  if (x < rect.width * 0.35) {
    showStoryItem(viewingStoryIndex - 1);
  } else {
    showStoryItem(viewingStoryIndex + 1);
  }
});

// Reply directly to story into DMs
btnSendStoryReply.addEventListener('click', sendStoryReply);
viewerReplyInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') sendStoryReply();
});

function sendStoryReply() {
  const text = viewerReplyInput.value.trim();
  if (!text) return;
  const currentStory = viewerStoriesList[viewingStoryIndex];
  store.sendMessage(viewingAuthor, {
    text,
    storyRef: currentStory.caption || 'Photo Story'
  });
  viewerReplyInput.value = '';
  showToast('Reply sent to their DMs ✉️');
}

// Viewers List Sheet
const modalViewersSheet = document.getElementById('modal-viewers-sheet');
const btnOpenViewersList = document.getElementById('btn-open-viewers-list');
const viewersListEl = document.getElementById('viewers-list');

btnOpenViewersList.addEventListener('click', () => {
  clearInterval(storyTimer);
  const currentStory = viewerStoriesList[viewingStoryIndex];
  viewersListEl.innerHTML = '';
  if (currentStory.viewers.length === 0) {
    viewersListEl.innerHTML = '<p class="modal-subtext">No views yet.</p>';
  } else {
    currentStory.viewers.forEach(uid => {
      const u = store.users[uid];
      const row = document.createElement('div');
      row.className = 'person-item';
      row.innerHTML = `
        <div class="avatar avatar-sm" style="background-color: ${u?.color || '#7c5cff'}">${uid[0].toUpperCase()}</div>
        <div class="person-info"><div class="person-name-row">${uid}</div></div>
      `;
      viewersListEl.appendChild(row);
    });
  }
  modalViewersSheet.classList.add('active');
});

modalViewersSheet.querySelector('.btn-close-viewers').addEventListener('click', () => {
  modalViewersSheet.classList.remove('active');
  startStoryTimer();
});

// ---------------- MESSAGES & CHAT LOGIC ----------------
const conversationsList = document.getElementById('conversations-list');
const btnNewChat = document.getElementById('btn-new-chat');
const modalChat = document.getElementById('modal-chat');
const chatPeerAvatar = document.getElementById('chat-peer-avatar');
const chatPeerName = document.getElementById('chat-peer-name');
const chatMessagesScroll = document.getElementById('chat-messages-scroll');
const chatTextInput = document.getElementById('chat-text-input');
const chatPhotoInput = document.getElementById('chat-photo-input');
const chatVideoInput = document.getElementById('chat-video-input');
const btnSendChat = document.getElementById('btn-send-chat');
const modalVideoPlayer = document.getElementById('modal-video-player');
const isolatedVideoEl = document.getElementById('isolated-video-el');

let currentChatPeer = null;

function renderConversations() {
  if (!store.me) return;
  const convos = store.getConversations();
  conversationsList.innerHTML = '';

  if (convos.length === 0) {
    conversationsList.innerHTML = '<p class="modal-subtext" style="text-align:center; padding:30px;">No messages yet. Direct connections only.</p>';
    return;
  }

  convos.forEach(peer => {
    const thread = store.getThread(peer);
    const last = thread[thread.length - 1];
    const u = store.users[peer];
    let preview = last.text || '';
    if (last.image) preview = '📷 Photo';
    if (last.video) preview = '🎬 Video';
    if (last.from === store.me) preview = 'You: ' + preview;

    const el = document.createElement('div');
    el.className = 'convo-item';
    el.innerHTML = `
      <div class="avatar" style="background-color: ${u?.color || '#7c5cff'}">${peer[0].toUpperCase()}</div>
      <div class="convo-info">
        <div class="convo-name">${peer}</div>
        <div class="convo-snippet">${preview}</div>
      </div>
      <div class="convo-time">${formatTimeAgo(last.time)}</div>
    `;
    el.addEventListener('click', () => openChat(peer));
    conversationsList.appendChild(el);
  });
}

function openChat(peer) {
  currentChatPeer = peer;
  const u = store.users[peer];
  chatPeerName.textContent = peer;
  chatPeerAvatar.textContent = peer[0].toUpperCase();
  chatPeerAvatar.style.backgroundColor = u?.color || '#7c5cff';
  modalChat.classList.add('active');
  renderChatMessages();
}

function renderChatMessages() {
  if (!currentChatPeer) return;
  const thread = store.getThread(currentChatPeer);
  chatMessagesScroll.innerHTML = '';

  thread.forEach(msg => {
    const isMine = msg.from === store.me;
    const bubble = document.createElement('div');
    bubble.className = `chat-bubble ${isMine ? 'mine' : 'peer'}`;

    if (msg.storyRef) {
      const ref = document.createElement('div');
      ref.className = 'chat-story-ref';
      ref.textContent = `↩ Replied to story: ${msg.storyRef}`;
      bubble.appendChild(ref);
    }

    if (msg.image) {
      const img = document.createElement('img');
      img.className = 'chat-media-thumb';
      img.src = msg.image;
      img.alt = 'Photo';
      img.addEventListener('click', () => {
        window.open(msg.image, '_blank');
      });
      bubble.appendChild(img);
    }

    if (msg.video) {
      const vidBadge = document.createElement('div');
      vidBadge.className = 'chat-video-badge';
      vidBadge.innerHTML = `
        <svg viewBox="0 0 24 24" width="36" height="36" fill="white"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        <span style="font-size:12px; font-weight:600;">Play Isolated Video</span>
      `;
      vidBadge.addEventListener('click', () => playIsolatedVideo(msg.video));
      bubble.appendChild(vidBadge);
    }

    if (msg.text) {
      const p = document.createElement('p');
      p.textContent = msg.text;
      bubble.appendChild(p);
    }

    chatMessagesScroll.appendChild(bubble);
  });

  chatMessagesScroll.scrollTop = chatMessagesScroll.scrollHeight;
}

btnSendChat.addEventListener('click', sendChatMessage);
chatTextInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') sendChatMessage();
});

function sendChatMessage() {
  const text = chatTextInput.value.trim();
  if (!text || !currentChatPeer) return;
  store.sendMessage(currentChatPeer, { text });
  chatTextInput.value = '';
  renderChatMessages();
  renderConversations();
}

chatPhotoInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file || !currentChatPeer) return;
  const reader = new FileReader();
  reader.onload = (event) => {
    store.sendMessage(currentChatPeer, { image: event.target.result });
    renderChatMessages();
    renderConversations();
  };
  reader.readAsDataURL(file);
});

chatVideoInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file || !currentChatPeer) return;
  const reader = new FileReader();
  reader.onload = (event) => {
    store.sendMessage(currentChatPeer, { video: event.target.result });
    renderChatMessages();
    renderConversations();
  };
  reader.readAsDataURL(file);
});

modalChat.querySelector('.btn-close-chat').addEventListener('click', () => {
  modalChat.classList.remove('active');
  currentChatPeer = null;
  renderConversations();
});

btnNewChat.addEventListener('click', () => {
  const others = Object.keys(store.users).filter(u => u !== store.me);
  const peer = prompt('Enter username to message:\n' + others.join(', '));
  if (peer && store.users[peer.trim().toLowerCase()]) {
    openChat(peer.trim().toLowerCase());
  }
});

// Isolated Video Playback
function playIsolatedVideo(src) {
  isolatedVideoEl.src = src;
  modalVideoPlayer.classList.add('active');
  isolatedVideoEl.play();
}

modalVideoPlayer.querySelector('.btn-close-video').addEventListener('click', () => {
  isolatedVideoEl.pause();
  isolatedVideoEl.src = '';
  modalVideoPlayer.classList.remove('active');
});

// ---------------- PEOPLE SEARCH & FOLLOW LOGIC ----------------
const peopleListEl = document.getElementById('people-list');
const peopleSearchInput = document.getElementById('people-search-input');

function renderPeople() {
  if (!store.me) return;
  const query = peopleSearchInput.value.trim().toLowerCase();
  const allUsers = Object.keys(store.users).filter(u => u !== store.me);
  const filtered = allUsers.filter(u => u.includes(query));

  peopleListEl.innerHTML = '';
  filtered.forEach(uid => {
    const u = store.users[uid];
    const isFollowing = store.isFollowing(uid);
    const hasRequested = store.hasRequested(uid);
    const followsMe = store.followsMe(uid);

    let actionBtnHtml = '';
    if (isFollowing) {
      actionBtnHtml = `<button class="btn btn-outline btn-sm btn-unfollow" data-uid="${uid}">Following</button>`;
    } else if (hasRequested) {
      actionBtnHtml = `<button class="btn btn-outline btn-sm btn-cancel-req" data-uid="${uid}">Requested</button>`;
    } else {
      actionBtnHtml = `<button class="btn btn-primary btn-sm btn-follow" data-uid="${uid}">${followsMe ? 'Follow back' : 'Follow'}</button>`;
    }

    const row = document.createElement('div');
    row.className = 'person-item';
    row.innerHTML = `
      <div class="avatar" style="background-color: ${u.color || '#7c5cff'}">${uid[0].toUpperCase()}</div>
      <div class="person-info">
        <div class="person-name-row">
          <span>${uid}</span>
          ${u.isPrivate ? '<svg class="private-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>' : ''}
        </div>
        <div class="person-bio">${u.bio}</div>
      </div>
      <div class="person-actions">
        <button class="icon-btn btn-msg-user" data-uid="${uid}">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
        </button>
        ${actionBtnHtml}
      </div>
    `;

    row.querySelector('.btn-msg-user').addEventListener('click', () => openChat(uid));
    const actionBtn = row.querySelector('.btn-follow, .btn-unfollow, .btn-cancel-req');
    if (actionBtn) {
      actionBtn.addEventListener('click', () => {
        if (actionBtn.classList.contains('btn-follow')) store.follow(uid);
        else if (actionBtn.classList.contains('btn-unfollow')) store.unfollow(uid);
        else if (actionBtn.classList.contains('btn-cancel-req')) store.cancelRequest(uid);
        renderAll();
      });
    }

    peopleListEl.appendChild(row);
  });
}

peopleSearchInput.addEventListener('input', renderPeople);

// ---------------- PROFILE LOGIC ----------------
const profileAvatar = document.getElementById('profile-avatar');
const profileUsername = document.getElementById('profile-username');
const profileBio = document.getElementById('profile-bio');
const statFollowing = document.getElementById('stat-following');
const statFollowers = document.getElementById('stat-followers');
const settingPrivate = document.getElementById('setting-private');
const btnEditBio = document.getElementById('btn-edit-bio');
const requestsBadge = document.getElementById('requests-badge');
const requestsNavDot = document.getElementById('requests-nav-dot');
const nfbCount = document.getElementById('nfb-count');
const btnLogout = document.getElementById('btn-logout');

function renderProfile() {
  if (!store.me) return;
  const me = store.users[store.me];
  profileUsername.textContent = '@' + me.id;
  profileAvatar.textContent = me.id[0].toUpperCase();
  profileAvatar.style.backgroundColor = me.color || '#7c5cff';
  profileBio.textContent = me.bio || 'No bio yet.';

  const followingList = store.following[store.me] || [];
  const followersList = store.getFollowers();
  statFollowing.textContent = followingList.length;
  statFollowers.textContent = followersList.length;

  settingPrivate.checked = !!me.isPrivate;

  const reqs = store.getIncomingRequests();
  requestsBadge.textContent = reqs.length;
  if (reqs.length > 0) {
    requestsNavDot.classList.remove('hidden');
  } else {
    requestsNavDot.classList.add('hidden');
  }

  const nfb = store.getNotFollowingBack();
  nfbCount.textContent = nfb.length;
}

settingPrivate.addEventListener('change', () => {
  if (store.me && store.users[store.me]) {
    store.users[store.me].isPrivate = settingPrivate.checked;
    store.save();
    showToast(settingPrivate.checked ? 'Account is now Private 🔒' : 'Account is now Public 🌍');
  }
});

btnEditBio.addEventListener('click', () => {
  const current = store.users[store.me]?.bio || '';
  const val = prompt('Edit your bio:', current);
  if (val !== null) {
    store.users[store.me].bio = val.trim();
    store.save();
    renderProfile();
  }
});

btnLogout.addEventListener('click', () => {
  if (confirm('Are you sure you want to log out?')) {
    store.logout();
    checkAuth();
  }
});

// Follow Requests Modal
const modalRequests = document.getElementById('modal-requests');
const btnOpenRequests = document.getElementById('btn-open-requests');
const requestsListEl = document.getElementById('requests-list');

btnOpenRequests.addEventListener('click', () => {
  const reqs = store.getIncomingRequests();
  requestsListEl.innerHTML = '';
  if (reqs.length === 0) {
    requestsListEl.innerHTML = '<p class="modal-subtext">No pending follow requests.</p>';
  } else {
    reqs.forEach(from => {
      const u = store.users[from];
      const row = document.createElement('div');
      row.className = 'person-item';
      row.innerHTML = `
        <div class="avatar avatar-sm" style="background-color: ${u?.color || '#7c5cff'}">${from[0].toUpperCase()}</div>
        <div class="person-info"><div class="person-name-row">${from}</div></div>
        <div class="person-actions">
          <button class="btn btn-primary btn-sm btn-accept" data-from="${from}">Accept</button>
          <button class="btn btn-outline btn-sm btn-delete" data-from="${from}">Delete</button>
        </div>
      `;
      row.querySelector('.btn-accept').addEventListener('click', () => {
        store.acceptRequest(from);
        btnOpenRequests.click();
        renderAll();
      });
      row.querySelector('.btn-delete').addEventListener('click', () => {
        store.deleteRequest(from);
        btnOpenRequests.click();
        renderAll();
      });
      requestsListEl.appendChild(row);
    });
  }
  modalRequests.classList.add('active');
});

modalRequests.querySelector('.btn-close-requests').addEventListener('click', () => {
  modalRequests.classList.remove('active');
});

// Not Following Back Modal (Unscroll)
const modalNfb = document.getElementById('modal-nfb');
const btnOpenNfb = document.getElementById('btn-open-not-following-back');
const nfbListEl = document.getElementById('nfb-list');

btnOpenNfb.addEventListener('click', () => {
  const nfb = store.getNotFollowingBack();
  nfbListEl.innerHTML = '';
  if (nfb.length === 0) {
    nfbListEl.innerHTML = '<p class="modal-subtext" style="text-align:center; padding:20px;">Everyone you follow follows you back 🎉</p>';
  } else {
    nfb.forEach(uid => {
      const u = store.users[uid];
      const row = document.createElement('div');
      row.className = 'person-item';
      row.innerHTML = `
        <div class="avatar avatar-sm" style="background-color: ${u?.color || '#7c5cff'}">${uid[0].toUpperCase()}</div>
        <div class="person-info">
          <div class="person-name-row">${uid}</div>
          <div class="person-bio">${u?.bio || ''}</div>
        </div>
        <button class="btn btn-tonal btn-sm btn-unfollow-instant" data-uid="${uid}">Unfollow</button>
      `;
      row.querySelector('.btn-unfollow-instant').addEventListener('click', () => {
        store.unfollow(uid);
        btnOpenNfb.click();
        renderAll();
      });
      nfbListEl.appendChild(row);
    });
  }
  modalNfb.classList.add('active');
});

modalNfb.querySelector('.btn-close-nfb').addEventListener('click', () => {
  modalNfb.classList.remove('active');
});

// ---------------- INSTAGRAM AUDIT TOOL LOGIC ----------------
const modalIgAudit = document.getElementById('modal-ig-audit');
const btnOpenIgAudit = document.getElementById('btn-open-ig-audit');
const igImportView = document.getElementById('ig-import-view');
const igResultsView = document.getElementById('ig-results-view');
const igFileInput = document.getElementById('ig-file-input');
const igPasteFollowers = document.getElementById('ig-paste-followers');
const igPasteFollowing = document.getElementById('ig-paste-following');
const btnProcessPasted = document.getElementById('btn-process-pasted');
const btnResetIgData = document.getElementById('btn-reset-ig-data');
const igCountFollowing = document.getElementById('ig-count-following');
const igCountFollowers = document.getElementById('ig-count-followers');
const igTabNfbCount = document.getElementById('ig-tab-nfb-count');
const igTabFansCount = document.getElementById('ig-tab-fans-count');
const igTabMutualCount = document.getElementById('ig-tab-mutual-count');
const igTabContent = document.getElementById('ig-tab-content');
const igSearchFilter = document.getElementById('ig-search-filter');
const igTabBtns = document.querySelectorAll('.ig-tab-btn');

let currentIgTab = 'not-back';

btnOpenIgAudit.addEventListener('click', () => {
  modalIgAudit.classList.add('active');
  renderIgAudit();
});

modalIgAudit.querySelector('.btn-close-ig').addEventListener('click', () => {
  modalIgAudit.classList.remove('active');
});

function parseIgExportJson(raw) {
  try {
    const j = typeof raw === 'string' ? JSON.parse(raw) : raw;
    const list = Array.isArray(j) ? j : Object.values(j).find(v => Array.isArray(v)) || [];
    const set = new Set();

    list.forEach(item => {
      if (!item || typeof item !== 'object') return;
      const dataList = item.string_list_data || [];
      const entry = dataList[0] || {};
      let name = (entry.value || item.title || '').trim();
      if (!name && entry.href) {
        const parts = entry.href.split('/').filter(Boolean);
        name = parts[parts.length - 1] || '';
      }
      if (name) set.add(name.toLowerCase());
    });
    return Array.from(set);
  } catch (e) {
    return [];
  }
}

function processIgFiles(files) {
  let fers = new Set(store.igFollowers);
  let fing = new Set(store.igFollowing);
  let filesProcessed = 0;

  Array.from(files).forEach(file => {
    const name = file.name.toLowerCase();
    if (!name.endsWith('.json')) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      const parsed = parseIgExportJson(e.target.result);
      if (name.includes('follower')) {
        parsed.forEach(x => fers.add(x));
      } else if (name.includes('following')) {
        parsed.forEach(x => fing.add(x));
      }
      filesProcessed++;
      if (filesProcessed === files.length) {
        if (fers.size === 0 || fing.size === 0) {
          showToast('Please upload both followers and following JSON files.');
          return;
        }
        store.igFollowers = Array.from(fers);
        store.igFollowing = Array.from(fing);
        store.saveIg();
        showToast(`Analyzed ${store.igFollowing.length} following and ${store.igFollowers.length} followers!`);
        renderIgAudit();
      }
    };
    reader.readAsText(file);
  });
}

igFileInput.addEventListener('change', (e) => {
  if (e.target.files.length > 0) processIgFiles(e.target.files);
});

// Drag & drop support
const igDropzone = document.getElementById('ig-dropzone');
igDropzone.addEventListener('dragover', (e) => {
  e.preventDefault();
  igDropzone.style.borderColor = 'var(--accent-purple)';
});
igDropzone.addEventListener('dragleave', () => {
  igDropzone.style.borderColor = 'var(--border-color)';
});
igDropzone.addEventListener('drop', (e) => {
  e.preventDefault();
  igDropzone.style.borderColor = 'var(--border-color)';
  if (e.dataTransfer.files.length > 0) processIgFiles(e.dataTransfer.files);
});

btnProcessPasted.addEventListener('click', () => {
  const fers = parseIgExportJson(igPasteFollowers.value);
  const fing = parseIgExportJson(igPasteFollowing.value);
  if (fers.length === 0 || fing.length === 0) {
    showToast('Could not parse JSON. Paste followers into field 1 and following into field 2.');
    return;
  }
  store.igFollowers = fers;
  store.igFollowing = fing;
  store.saveIg();
  showToast(`Loaded ${fing.length} following & ${fers.length} followers`);
  renderIgAudit();
});

btnResetIgData.addEventListener('click', () => {
  if (confirm('Clear imported Instagram export data?')) {
    store.igFollowers = [];
    store.igFollowing = [];
    store.igDone = [];
    store.saveIg();
    renderIgAudit();
  }
});

igTabBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    igTabBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentIgTab = btn.dataset.igTab;
    renderIgResultsList();
  });
});

igSearchFilter.addEventListener('input', renderIgResultsList);

function renderIgAudit() {
  const hasData = store.igFollowers.length > 0 && store.igFollowing.length > 0;
  if (!hasData) {
    igImportView.classList.remove('hidden');
    igResultsView.classList.add('hidden');
  } else {
    igImportView.classList.add('hidden');
    igResultsView.classList.remove('hidden');

    const followingSet = new Set(store.igFollowing);
    const followerSet = new Set(store.igFollowers);

    const nfb = store.igFollowing.filter(u => !followerSet.has(u));
    const fans = store.igFollowers.filter(u => !followingSet.has(u));
    const mutual = store.igFollowing.filter(u => followerSet.has(u));

    igCountFollowing.textContent = `${store.igFollowing.length} Following`;
    igCountFollowers.textContent = `${store.igFollowers.length} Followers`;
    igTabNfbCount.textContent = nfb.length;
    igTabFansCount.textContent = fans.length;
    igTabMutualCount.textContent = mutual.length;

    renderIgResultsList();
  }
}

function renderIgResultsList() {
  const followingSet = new Set(store.igFollowing);
  const followerSet = new Set(store.igFollowers);
  let list = [];

  if (currentIgTab === 'not-back') {
    list = store.igFollowing.filter(u => !followerSet.has(u));
  } else if (currentIgTab === 'fans') {
    list = store.igFollowers.filter(u => !followingSet.has(u));
  } else {
    list = store.igFollowing.filter(u => followerSet.has(u));
  }

  const query = igSearchFilter.value.trim().toLowerCase();
  if (query) list = list.filter(u => u.includes(query));

  igTabContent.innerHTML = '';
  if (list.length === 0) {
    igTabContent.innerHTML = '<p class="modal-subtext" style="text-align:center; padding:20px;">No users found in this list.</p>';
    return;
  }

  list.forEach(username => {
    const isDone = store.igDone.includes(username);
    const row = document.createElement('div');
    row.className = 'ig-row';
    row.innerHTML = `
      <div class="ig-row-user ${isDone ? 'done' : ''}">
        <input type="checkbox" class="ig-checkbox" ${isDone ? 'checked' : ''} data-u="${username}">
        <span>${username}</span>
      </div>
      <a href="https://www.instagram.com/${username}/" target="_blank" rel="noopener noreferrer" class="btn btn-outline btn-sm">
        ${currentIgTab === 'not-back' ? 'Open to Unfollow' : 'Open Profile'}
      </a>
    `;

    row.querySelector('.ig-checkbox').addEventListener('change', (e) => {
      if (e.target.checked) {
        if (!store.igDone.includes(username)) store.igDone.push(username);
      } else {
        store.igDone = store.igDone.filter(x => x !== username);
      }
      store.saveIg();
      row.querySelector('.ig-row-user').classList.toggle('done', e.target.checked);
    });

    igTabContent.appendChild(row);
  });
}

// ---------------- UTILS & RENDER CYCLE ----------------
function formatTimeAgo(ms) {
  const diffSec = Math.floor((Date.now() - ms) / 1000);
  if (diffSec < 60) return 'now';
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h`;
  return `${Math.floor(diffHr / 24)}d`;
}

function showToast(msg) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 2500);
}

function renderAll() {
  renderStories();
  renderConversations();
  renderPeople();
  renderProfile();
}

// Initial bootstrap
checkAuth();
