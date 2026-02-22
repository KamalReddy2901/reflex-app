/* ═══════════════════════════════════════════════════════════
   Reflex Landing Page — Main Script
   ═══════════════════════════════════════════════════════════ */

'use strict';

/* ── GitHub Release API ──────────────────────────────────── */
const REPO = 'KamalReddy2901/reflex';
const API_URL = `https://api.github.com/repos/${REPO}/releases/latest`;
const FALLBACK_VERSION = 'v2.0.2';
const FALLBACK_DMG = `https://github.com/${REPO}/releases/latest/download/Reflex-2.0.2.dmg`;

async function fetchLatestRelease() {
  try {
    const res = await fetch(API_URL, {
      headers: { 'Accept': 'application/vnd.github+json' },
      cache: 'no-cache'
    });
    if (!res.ok) throw new Error(`GitHub API: ${res.status}`);
    const data = await res.json();

    const version = data.tag_name || FALLBACK_VERSION;
    const cleanVersion = version.startsWith('v') ? version : `v${version}`;

    // Find the DMG asset
    const dmgAsset = data.assets && data.assets.find(a => a.name.endsWith('.dmg'));
    const dmgUrl = dmgAsset ? dmgAsset.browser_download_url : FALLBACK_DMG;

    applyReleaseInfo(cleanVersion, dmgUrl);
  } catch (err) {
    console.warn('Could not fetch release info, using fallback.', err);
    applyReleaseInfo(FALLBACK_VERSION, FALLBACK_DMG);
  }
}

function applyReleaseInfo(version, dmgUrl) {
  // Update all download buttons
  const downloadBtns = document.querySelectorAll(
    '#main-download-btn, #hero-download-btn'
  );
  downloadBtns.forEach(btn => {
    btn.href = dmgUrl;
    btn.setAttribute('download', '');
  });

  // Update version badges
  const versionEls = document.querySelectorAll('#dl-version, #sidebar-version');
  versionEls.forEach(el => { el.textContent = version; });
}

/* ── Navbar Scroll Effect ────────────────────────────────── */
function initNavbar() {
  const navbar = document.getElementById('navbar');
  let ticking = false;

  function updateNavbar() {
    if (window.scrollY > 40) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
    ticking = false;
  }

  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(updateNavbar);
      ticking = true;
    }
  }, { passive: true });
}

/* ── Mobile Menu ─────────────────────────────────────────── */
function initMobileMenu() {
  const hamburger = document.getElementById('hamburger');
  const navLinks = document.getElementById('nav-links');

  hamburger.addEventListener('click', () => {
    const isOpen = navLinks.classList.toggle('open');
    hamburger.classList.toggle('open', isOpen);
    hamburger.setAttribute('aria-expanded', isOpen);
    // Prevent body scroll when menu open
    document.body.style.overflow = isOpen ? 'hidden' : '';
  });

  // Close on nav link click
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      hamburger.classList.remove('open');
      hamburger.setAttribute('aria-expanded', false);
      document.body.style.overflow = '';
    });
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!hamburger.contains(e.target) && !navLinks.contains(e.target)) {
      navLinks.classList.remove('open');
      hamburger.classList.remove('open');
      document.body.style.overflow = '';
    }
  });
}

/* ── Smooth Scroll for Anchor Links ─────────────────────── */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const target = document.querySelector(this.getAttribute('href'));
      if (!target) return;
      e.preventDefault();
      const offset = parseInt(getComputedStyle(document.documentElement)
        .getPropertyValue('--nav-h')) || 68;
      const top = target.getBoundingClientRect().top + window.scrollY - offset - 16;
      window.scrollTo({ top, behavior: 'smooth' });
    });
  });
}

/* ── Scroll Reveal (IntersectionObserver) ────────────────── */
function initReveal() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        // For signal bars — trigger fill animation
        const fill = entry.target.querySelector('.signal-fill');
        if (fill) {
          const targetW = fill.style.width;
          fill.style.setProperty('--target-w', targetW);
          entry.target.classList.add('visible');
        }
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12,
    rootMargin: '0px 0px -40px 0px'
  });

  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

  // Signal bars get special treatment — pre-store their target width
  document.querySelectorAll('.signal-item').forEach(item => {
    const fill = item.querySelector('.signal-fill');
    if (fill) {
      const tw = fill.style.width;
      fill.dataset.targetW = tw;
      fill.style.width = '0';
    }
  });

  // Second observer for signal items specifically (re-trigger fill on visible)
  const signalObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const fill = entry.target.querySelector('.signal-fill');
        if (fill && fill.dataset.targetW) {
          // Small delay so the bar animation is visible
          setTimeout(() => {
            fill.style.width = fill.dataset.targetW;
          }, 150);
        }
      }
    });
  }, { threshold: 0.3 });

  document.querySelectorAll('.signal-item').forEach(el => signalObserver.observe(el));
}

/* ── Animated Score Counter in Hero ─────────────────────── */
function initHeroScore() {
  const el = document.getElementById('animated-score');
  if (!el) return;

  // Animate from 0 to a "live" value that slowly fluctuates
  const targetScore = 72;
  let current = 0;
  const duration = 1800;
  const start = performance.now();

  function animate(now) {
    const elapsed = now - start;
    const progress = Math.min(elapsed / duration, 1);
    // Ease out cubic
    const eased = 1 - Math.pow(1 - progress, 3);
    current = Math.round(eased * targetScore);
    el.textContent = current;

    if (progress < 1) {
      requestAnimationFrame(animate);
    } else {
      // After initial animation, slowly fluctuate the score
      startScoreFluctuation(el, targetScore);
    }
  }

  // Start after a brief delay (page loads, reveal triggers)
  setTimeout(() => requestAnimationFrame(animate), 600);
}

function startScoreFluctuation(el, base) {
  // Simulate a live cognitive load score that slowly moves
  let current = base;
  let direction = 1;
  let steps = 0;

  const colors = {
    flow:     { max: 25, label: 'Flow',      color: '#34D399' },
    moderate: { max: 50, label: 'Moderate',  color: '#FBBF24' },
    elevated: { max: 75, label: 'Elevated',  color: '#F97316' },
    overload: { max: 100, label: 'Overloaded',color: '#EF4444' },
  };

  function getLevel(score) {
    if (score <= 25) return colors.flow;
    if (score <= 50) return colors.moderate;
    if (score <= 75) return colors.elevated;
    return colors.overload;
  }

  const labelEl = el.nextElementSibling;
  const ringCircle = document.querySelector('.hero-ring circle:nth-child(2)');

  setInterval(() => {
    if (steps > 12) { direction *= -1; steps = 0; }
    const delta = Math.random() * 2.5;
    current = Math.round(Math.max(45, Math.min(85, current + direction * delta)));
    steps++;

    el.textContent = current;

    const level = getLevel(current);
    if (labelEl) { labelEl.textContent = level.label; labelEl.style.color = level.color; }

    // Update ring dash offset to match score
    if (ringCircle) {
      const circ = 2 * Math.PI * 85; // r=85
      const filled = (current / 100) * circ * 0.75; // 75% max arc
      const offset = circ - filled;
      ringCircle.style.strokeDashoffset = offset;
    }
  }, 2200);
}

/* ── Download tracking (analytics-free, just UX feedback) ── */
function initDownloadFeedback() {
  const mainBtn = document.getElementById('main-download-btn');
  if (!mainBtn) return;

  mainBtn.addEventListener('click', () => {
    // Brief visual feedback on the button
    mainBtn.style.transform = 'scale(0.97)';
    setTimeout(() => { mainBtn.style.transform = ''; }, 200);

    // Smoothly scroll to install guide if not already past it
    const installSection = document.getElementById('install');
    if (installSection) {
      const rect = installSection.getBoundingClientRect();
      // Only scroll to install if it's below current viewport
      if (rect.top > window.innerHeight * 1.5) {
        setTimeout(() => {
          const offset = parseInt(getComputedStyle(document.documentElement)
            .getPropertyValue('--nav-h')) || 68;
          const top = installSection.getBoundingClientRect().top + window.scrollY - offset - 16;
          window.scrollTo({ top, behavior: 'smooth' });
        }, 800);
      }
    }
  });
}

/* ── Active nav link highlighting ───────────────────────── */
function initActiveNav() {
  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
  const navH = 80;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.getAttribute('id');
        navLinks.forEach(link => {
          link.classList.toggle('active', link.getAttribute('href') === `#${id}`);
        });
      }
    });
  }, {
    rootMargin: `-${navH}px 0px -60% 0px`,
    threshold: 0
  });

  sections.forEach(s => observer.observe(s));
}

/* ── CSS for active nav links (injected dynamically) ────── */
function injectActiveNavStyle() {
  const style = document.createElement('style');
  style.textContent = `.nav-links a.active { color: var(--text) !important; }`;
  document.head.appendChild(style);
}

/* ── Hero badge pulse for accessibility ─────────────────── */
function initHeroBadge() {
  // Make the live badge slightly pulse to indicate real-time nature
  const dot = document.querySelector('.badge-dot');
  if (!dot) return;
  // CSS handles the animation; just ensure :focus styles are good
}

/* ── Prefers-reduced-motion respect ─────────────────────── */
function respectReducedMotion() {
  const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
  if (mq.matches) {
    document.documentElement.style.setProperty('--transition-duration', '0.01ms');
    // Remove orb animations
    document.querySelectorAll('.hero-orb, .icon-glow').forEach(el => {
      el.style.animation = 'none';
    });
  }
}

/* ── Init ────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  respectReducedMotion();
  injectActiveNavStyle();
  initNavbar();
  initMobileMenu();
  initSmoothScroll();
  initReveal();
  initHeroScore();
  initDownloadFeedback();
  initActiveNav();
  fetchLatestRelease();
});
