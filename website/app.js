// T69 Esports Landing Page JS

document.addEventListener('DOMContentLoaded', () => {
  // 1. Initialize Lucide Icons
  if (window.lucide) {
    window.lucide.createIcons();
  }

  // 2. Mobile Menu Toggle
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const mobileMenu = document.getElementById('mobileMenu');
  if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
    });

    // Close on navigation link tap
    mobileMenu.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        mobileMenu.classList.add('hidden');
      });
    });
  }

  // 3. FAQ Accordion Toggle
  const faqToggles = document.querySelectorAll('.faq-toggle');
  faqToggles.forEach(toggle => {
    toggle.addEventListener('click', () => {
      const card = toggle.closest('.app-card');
      const content = card.querySelector('.faq-content');
      const icon = toggle.querySelector('i[data-lucide="chevron-down"], svg');

      const isHidden = content.classList.contains('hidden');

      // Close all FAQs first
      document.querySelectorAll('.faq-content').forEach(c => c.classList.add('hidden'));
      document.querySelectorAll('.faq-toggle i, .faq-toggle svg').forEach(i => i.classList.remove('rotate-180'));

      // Open selected if it was closed
      if (isHidden) {
        content.classList.remove('hidden');
        if (icon) icon.classList.add('rotate-180');
      }
    });
  });

  // 4. Download Trigger with Feedback Toast
  const downloadButtons = document.querySelectorAll('.download-trigger');
  const downloadToast = document.getElementById('downloadToast');

  downloadButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      if (downloadToast) {
        downloadToast.classList.remove('hidden');
        downloadToast.classList.add('flex');
        
        setTimeout(() => {
          downloadToast.classList.add('hidden');
          downloadToast.classList.remove('flex');
        }, 5000);
      }
    });
  });
});