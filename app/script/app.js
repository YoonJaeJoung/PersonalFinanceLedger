document.addEventListener('DOMContentLoaded', () => {
  // --- Element References ---
  const tableHeaderEl = document.getElementById('table-header');
  const tableBodyEl = document.getElementById('table-body');
  const balanceRowEl = document.getElementById('balance-row');
  const emptyStateEl = document.getElementById('empty-state');
  const deleteSelectedBtn = document.getElementById('delete-selected-btn');
  const deleteCountEl = document.getElementById('delete-count');
  const changeAccountGroup = document.getElementById('change-account-group');
  const changeAccountSelect = document.getElementById('change-account-select');
  const changeAccountBtn = document.getElementById('change-account-btn');

  // Account bar
  const filterAccountEl = document.getElementById('filter-account');
  const filterToggleBtn = document.getElementById('filter-toggle-btn');
  const filterPanel = document.getElementById('filter-panel');

  // Filter elements
  const filterDescription = document.getElementById('filter-description');
  const filterCategoryEl = document.getElementById('filter-category');
  const filterAmountMin = document.getElementById('filter-amount-min');
  const filterAmountMax = document.getElementById('filter-amount-max');
  const filterDateStart = document.getElementById('filter-date-start');
  const filterDateEnd = document.getElementById('filter-date-end');
  const filterApplyBtn = document.getElementById('filter-apply-btn');
  const filterResetBtn = document.getElementById('filter-reset-btn');

  // Input bar elements
  const toggleTypeBtn = document.getElementById('toggle-type');
  const inputAccount = document.getElementById('input-account');
  const inputDate = document.getElementById('input-date');
  const inputDescription = document.getElementById('input-description');
  const inputCategory = document.getElementById('input-category');
  const inputAmount = document.getElementById('input-amount');
  const submitBtn = document.getElementById('submit-row');
  const autocompleteDropdown = document.getElementById('category-autocomplete');

  // Sidebar tabs
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabData = document.getElementById('tab-data');
  const tabSummary = document.getElementById('tab-summary');

  // --- Category Color Map ---
  const CATEGORY_COLORS = {
    'Groceries': { bg: 'rgba(239, 68, 68, 0.12)', text: '#f87171', border: 'rgba(239, 68, 68, 0.3)' },
    'Food': { bg: 'rgba(251, 146, 60, 0.12)', text: '#fb923c', border: 'rgba(251, 146, 60, 0.3)' },
    'Restaurant Week': { bg: 'rgba(245, 158, 11, 0.12)', text: '#f59e0b', border: 'rgba(245, 158, 11, 0.3)' },
    'NBA': { bg: 'rgba(16, 185, 129, 0.12)', text: '#10b981', border: 'rgba(16, 185, 129, 0.3)' },
    'Broadway': { bg: 'rgba(168, 85, 247, 0.12)', text: '#a855f7', border: 'rgba(168, 85, 247, 0.3)' },
    'Transportation': { bg: 'rgba(59, 130, 246, 0.12)', text: '#3b82f6', border: 'rgba(59, 130, 246, 0.3)' },
    'Medical': { bg: 'rgba(236, 72, 153, 0.12)', text: '#ec4899', border: 'rgba(236, 72, 153, 0.3)' },
    'Home': { bg: 'rgba(107, 114, 128, 0.12)', text: '#9ca3af', border: 'rgba(107, 114, 128, 0.3)' },
    'Etc': { bg: 'rgba(148, 163, 184, 0.12)', text: '#94a3b8', border: 'rgba(148, 163, 184, 0.3)' },
    'Allowance': { bg: 'rgba(34, 197, 94, 0.12)', text: '#22c55e', border: 'rgba(34, 197, 94, 0.3)' },
    'Gift': { bg: 'rgba(56, 189, 248, 0.12)', text: '#38bdf8', border: 'rgba(56, 189, 248, 0.3)' },
    'Boucher': { bg: 'rgba(192, 132, 252, 0.12)', text: '#c084fc', border: 'rgba(192, 132, 252, 0.3)' },
    'Refund': { bg: 'rgba(52, 211, 153, 0.12)', text: '#34d399', border: 'rgba(52, 211, 153, 0.3)' },
  };
  const DEFAULT_CAT_COLOR = { bg: 'rgba(255,255,255,0.06)', text: '#aaa', border: 'rgba(255,255,255,0.15)' };
  function getCategoryColor(cat) { return CATEGORY_COLORS[cat] || DEFAULT_CAT_COLOR; }

  // --- State ---
  let allData = {};
  let isExpense = true;
  let autocompleteIndex = -1;
  let editingRow = null; // track currently editing row

  const ACCOUNT_FILES = ['chase.csv', 'cash.csv', 'toss.csv', 'travellog.csv'];
  const INCOME_CATEGORIES = ['Allowance', 'Gift', 'Boucher', 'Refund', 'Etc'];
  const EXPENSE_CATEGORIES = ['Groceries', 'Food', 'Restaurant Week', 'NBA', 'Broadway', 'Transportation', 'Medical', 'Home', 'Etc'];

  // --- Helpers ---
  function getSelectedAccounts() {
    return Array.from(filterAccountEl.querySelectorAll('input[type="checkbox"]:checked')).map(cb => cb.value);
  }
  function getSelectedCategories() {
    return Array.from(filterCategoryEl.querySelectorAll('input[type="checkbox"]:checked')).map(cb => cb.value);
  }
  function getMergedRows() {
    const selected = getSelectedAccounts();
    let merged = [];
    selected.forEach(file => {
      const data = allData[file];
      if (data && data.rows) {
        data.rows.forEach((row, idx) => merged.push({ ...row, __account: file, __rowIndex: idx }));
      }
    });
    merged.sort((a, b) => (a.Date || '').localeCompare(b.Date || ''));
    return merged;
  }
  function getHeaders() { return ['Date', 'Category', 'Description', 'Account', 'Amount']; }
  function accountDisplayName(filename) {
    return filename.replace('.csv', '').replace(/^\w/, c => c.toUpperCase());
  }

  function updateDeleteBtn() {
    const checked = tableBodyEl.querySelectorAll('.row-select:checked');
    const count = checked.length;
    deleteCountEl.textContent = count;
    deleteSelectedBtn.classList.toggle('hidden', count === 0);
    changeAccountGroup.classList.toggle('hidden', count === 0);
  }

  // --- Filter Panel Toggle ---
  filterToggleBtn.addEventListener('click', () => {
    const isOpen = !filterPanel.classList.contains('hidden');
    filterPanel.classList.toggle('hidden', isOpen);
    filterToggleBtn.classList.toggle('open', !isOpen);
    filterToggleBtn.innerHTML = isOpen ? '&#9662; Filters' : '&#9652; Filters';
  });

  // --- Sidebar Tabs ---
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tabBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;
      tabData.classList.toggle('hidden', tab !== 'data');
      tabSummary.classList.toggle('hidden', tab !== 'summary');
      const accountBar = document.querySelector('.account-bar');
      const contentArea = document.querySelector('.content-area');
      const inputBar = document.querySelector('.input-bar');
      if (tab === 'summary') {
        accountBar.classList.add('hidden');
        filterPanel.classList.add('hidden');
        contentArea.classList.add('hidden');
        inputBar.classList.add('hidden');
      } else {
        accountBar.classList.remove('hidden');
        contentArea.classList.remove('hidden');
        inputBar.classList.remove('hidden');
      }
    });
  });

  // --- Income / Expense Toggle ---
  toggleTypeBtn.addEventListener('click', () => {
    isExpense = !isExpense;
    toggleTypeBtn.textContent = isExpense ? 'Expense' : 'Income';
    toggleTypeBtn.classList.toggle('expense', isExpense);
    toggleTypeBtn.classList.toggle('income', !isExpense);
    updateAutocompleteSuggestions();
  });

  // --- Data Fetching ---
  async function loadAccount(filename) {
    try {
      const res = await fetch('/api/data/' + encodeURIComponent(filename));
      if (!res.ok) { allData[filename] = { headers: getHeaders(), rows: [] }; return; }
      allData[filename] = await res.json();
    } catch (err) {
      console.error(`Error loading ${filename}:`, err);
      allData[filename] = { headers: getHeaders(), rows: [] };
    }
  }

  async function loadSelectedAndRender() {
    const selected = getSelectedAccounts();
    const toLoad = selected.filter(f => !allData[f]);
    if (toLoad.length > 0) await Promise.all(toLoad.map(f => loadAccount(f)));
    renderFilteredTable();
    setDefaultDate();
  }

  async function forceReloadAll() {
    const selected = getSelectedAccounts();
    await Promise.all(selected.map(f => loadAccount(f)));
    renderFilteredTable();
    setDefaultDate();
  }

  function setDefaultDate() {
    const merged = getMergedRows();
    if (merged.length > 0 && merged[merged.length - 1].Date) {
      inputDate.value = merged[merged.length - 1].Date;
    } else {
      inputDate.value = new Date().toISOString().split('T')[0];
    }
  }

  // --- Account checkboxes: instant apply ---
  filterAccountEl.addEventListener('change', () => {
    loadSelectedAndRender();
  });

  // --- Filtering ---
  function getFilteredRows() {
    const merged = getMergedRows();
    const descSearch = filterDescription.value.toLowerCase().trim();
    const selectedCats = new Set(getSelectedCategories());
    const amtMin = filterAmountMin.value !== '' ? parseFloat(filterAmountMin.value) : null;
    const amtMax = filterAmountMax.value !== '' ? parseFloat(filterAmountMax.value) : null;
    const dateStart = filterDateStart.value || null;
    const dateEnd = filterDateEnd.value || null;

    return merged.filter(row => {
      if (descSearch && !(row.Description || '').toLowerCase().includes(descSearch)) return false;
      if (row.Category && !selectedCats.has(row.Category)) return false;
      const amt = parseFloat(row.Amount);
      if (!isNaN(amt)) {
        const absAmt = Math.abs(amt);
        if (amtMin !== null && absAmt < amtMin) return false;
        if (amtMax !== null && absAmt > amtMax) return false;
      }
      if (dateStart && row.Date < dateStart) return false;
      if (dateEnd && row.Date > dateEnd) return false;
      return true;
    });
  }

  function renderFilteredTable() {
    const headers = getHeaders();
    const filtered = getFilteredRows();
    tableHeaderEl.innerHTML = '';
    tableBodyEl.innerHTML = '';
    balanceRowEl.innerHTML = '';

    if (getSelectedAccounts().length === 0) {
      emptyStateEl.classList.remove('hidden');
      emptyStateEl.querySelector('p').textContent = 'Select at least one account';
      return;
    }
    emptyStateEl.classList.add('hidden');

    // Select-all checkbox column
    const thSelect = document.createElement('th');
    thSelect.style.width = '36px';
    const selectAllCb = document.createElement('input');
    selectAllCb.type = 'checkbox';
    selectAllCb.className = 'select-all-cb';
    selectAllCb.addEventListener('change', () => {
      tableBodyEl.querySelectorAll('.row-select').forEach(cb => cb.checked = selectAllCb.checked);
      tableBodyEl.querySelectorAll('tr').forEach(tr => tr.classList.toggle('selected-row', selectAllCb.checked));
      updateDeleteBtn();
    });
    thSelect.appendChild(selectAllCb);
    tableHeaderEl.appendChild(thSelect);
    headers.forEach(h => {
      const th = document.createElement('th');
      th.textContent = h;
      if (h === 'Date') th.className = 'col-date';
      else if (h === 'Category') th.className = 'col-category';
      else if (h === 'Account') th.className = 'col-account';
      else if (h === 'Amount') th.className = 'col-amount';
      tableHeaderEl.appendChild(th);
    });

    if (filtered.length === 0) {
      const tr = document.createElement('tr');
      const td = document.createElement('td');
      td.colSpan = headers.length + 1;
      td.textContent = 'No matching records';
      td.style.textAlign = 'center';
      td.style.color = 'var(--text-secondary)';
      td.style.padding = '30px';
      tr.appendChild(td);
      tableBodyEl.appendChild(tr);
    } else {
      filtered.forEach(row => {
        const tr = document.createElement('tr');
        tr.dataset.account = row.__account;
        tr.dataset.rowIndex = row.__rowIndex;
        // Row selection checkbox
        const tdSelect = document.createElement('td');
        const rowCb = document.createElement('input');
        rowCb.type = 'checkbox';
        rowCb.className = 'row-select';
        rowCb.addEventListener('change', () => {
          tr.classList.toggle('selected-row', rowCb.checked);
          updateDeleteBtn();
        });
        tdSelect.appendChild(rowCb);
        tr.appendChild(tdSelect);
        headers.forEach(h => {
          const td = document.createElement('td');
          if (h === 'Date') td.className = 'col-date';
          else if (h === 'Category') td.className = 'col-category';
          else if (h === 'Account') td.className = 'col-account';
          else if (h === 'Amount') td.className = 'col-amount';
          if (h === 'Account') {
            const badge = document.createElement('span');
            badge.className = 'account-badge';
            badge.textContent = accountDisplayName(row.__account);
            td.appendChild(badge);
          } else if (h === 'Amount') {
            const val = row[h] || '';
            const num = parseFloat(val);
            if (!isNaN(num)) {
              td.textContent = '$' + Math.abs(num).toFixed(2);
              td.classList.add(num >= 0 ? 'amount-positive' : 'amount-negative');
            } else { td.textContent = val; }
          } else if (h === 'Category') {
            const val = row[h] || '';
            const color = getCategoryColor(val);
            const badge = document.createElement('span');
            badge.className = 'category-badge';
            badge.textContent = val;
            badge.style.backgroundColor = color.bg;
            badge.style.color = color.text;
            badge.style.border = `1px solid ${color.border}`;
            td.appendChild(badge);
          } else {
            td.textContent = row[h] || '';
          }
          tr.appendChild(td);
        });
        tr.addEventListener('dblclick', () => startEditRow(tr, row));
        tableBodyEl.appendChild(tr);
      });
    }

    // Balance row
    let balance = 0;
    filtered.forEach(row => {
      const amt = parseFloat(row.Amount);
      if (!isNaN(amt)) balance += amt;
    });
    // Empty cell for checkbox column in balance row
    const balSelectTd = document.createElement('td');
    balanceRowEl.appendChild(balSelectTd);
    headers.forEach((h, i) => {
      const td = document.createElement('td');
      if (i === 0) td.textContent = 'Balance';
      else if (h === 'Amount') {
        td.textContent = '$' + Math.abs(balance).toFixed(2);
        td.classList.add(balance >= 0 ? 'amount-positive' : 'amount-negative');
      }
      balanceRowEl.appendChild(td);
    });
    updateDeleteBtn();

    // If there's a pending edit from double-clicking while already editing
    if (pendingEditRow) {
      const pendingRow = pendingEditRow;
      pendingEditRow = null;
      const trs = tableBodyEl.querySelectorAll('tr');
      for (const newTr of trs) {
        if (newTr.dataset.account === pendingRow.__account &&
          newTr.dataset.rowIndex === String(pendingRow.__rowIndex)) {
          startEditRow(newTr, pendingRow);
          break;
        }
      }
    }
  }

  // --- Inline Row Editing ---
  let pendingEditRow = null; // to handle double-click while already editing

  function startEditRow(tr, row) {
    if (editingRow) {
      // Store pending edit info, re-render will pick it up
      pendingEditRow = row;
      editingRow = null;
      renderFilteredTable();
      return;
    }
    editingRow = tr;
    const headers = getHeaders();
    const originalValues = {};
    headers.forEach(h => originalValues[h] = row[h] || '');
    tr.classList.add('editing-row');
    tr.innerHTML = '';

    // Empty td for checkbox column
    const tdCheckPlaceholder = document.createElement('td');
    tr.appendChild(tdCheckPlaceholder);

    let editAutocompleteDropdown = null;
    let editAutocompleteIndex = -1;
    let categoryInput = null;

    headers.forEach(h => {
      const td = document.createElement('td');
      if (h === 'Account') {
        // Account dropdown
        const select = document.createElement('select');
        select.className = 'edit-input';
        ACCOUNT_FILES.forEach(f => {
          const opt = document.createElement('option');
          opt.value = f;
          opt.textContent = accountDisplayName(f);
          if (f === row.__account) opt.selected = true;
          select.appendChild(opt);
        });
        select.addEventListener('keydown', (e) => {
          if (e.key === 'Escape') { e.preventDefault(); cancelEdit(); }
          if (e.key === 'Enter') { e.preventDefault(); saveEditRow(tr, originalValues, row.__account); }
        });
        td.appendChild(select);
        tr.appendChild(td);
        return;
      }
      const input = document.createElement('input');
      input.className = 'edit-input';
      if (h === 'Date') {
        input.type = 'date';
        input.value = originalValues[h];
      } else if (h === 'Amount') {
        input.type = 'number';
        input.step = '0.01';
        input.value = Math.abs(parseFloat(originalValues[h]) || 0).toFixed(2);
      } else {
        input.type = 'text';
        input.value = originalValues[h];
      }
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') { e.preventDefault(); cancelEdit(); }
      });
      // Category autocomplete in edit mode
      if (h === 'Category') {
        categoryInput = input;
        input.autocomplete = 'off';
        td.style.position = 'relative';
        editAutocompleteDropdown = document.createElement('div');
        editAutocompleteDropdown.className = 'autocomplete-dropdown hidden';

        const updateEditAutocomplete = () => {
          const val = input.value.toLowerCase().trim();
          const origAmt = parseFloat(originalValues.Amount);
          const cats = (!isNaN(origAmt) && origAmt >= 0) ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;
          const matches = val ? cats.filter(c => c.toLowerCase().startsWith(val)) : [];
          if (matches.length === 0) {
            editAutocompleteDropdown.classList.add('hidden');
            editAutocompleteDropdown.innerHTML = '';
            editAutocompleteIndex = -1;
            return;
          }
          editAutocompleteDropdown.classList.remove('hidden');
          editAutocompleteDropdown.innerHTML = '';
          editAutocompleteIndex = -1;
          matches.forEach(m => {
            const div = document.createElement('div');
            div.className = 'autocomplete-item';
            const color = getCategoryColor(m);
            div.textContent = m;
            div.style.borderLeft = `3px solid ${color.text}`;
            div.addEventListener('mousedown', (e) => {
              e.preventDefault();
              input.value = m;
              editAutocompleteDropdown.classList.add('hidden');
            });
            editAutocompleteDropdown.appendChild(div);
          });
        };

        input.addEventListener('input', updateEditAutocomplete);
        input.addEventListener('focus', updateEditAutocomplete);
        input.addEventListener('blur', () => {
          setTimeout(() => editAutocompleteDropdown.classList.add('hidden'), 150);
        });
        input.addEventListener('keydown', (e) => {
          if (!editAutocompleteDropdown) return;
          const items = editAutocompleteDropdown.querySelectorAll('.autocomplete-item');
          if (e.key === 'ArrowDown' && items.length > 0) {
            e.preventDefault();
            editAutocompleteIndex = Math.min(editAutocompleteIndex + 1, items.length - 1);
            items.forEach((it, i) => it.classList.toggle('active', i === editAutocompleteIndex));
          } else if (e.key === 'ArrowUp' && items.length > 0) {
            e.preventDefault();
            editAutocompleteIndex = Math.max(editAutocompleteIndex - 1, 0);
            items.forEach((it, i) => it.classList.toggle('active', i === editAutocompleteIndex));
          } else if (e.key === 'Tab' && items.length > 0 && !editAutocompleteDropdown.classList.contains('hidden')) {
            e.preventDefault();
            const idx = editAutocompleteIndex >= 0 ? editAutocompleteIndex : 0;
            input.value = items[idx].textContent;
            editAutocompleteDropdown.classList.add('hidden');
          } else if (e.key === 'Enter') {
            if (!editAutocompleteDropdown.classList.contains('hidden') && items.length > 0) {
              e.preventDefault();
              const idx = editAutocompleteIndex >= 0 ? editAutocompleteIndex : 0;
              input.value = items[idx].textContent;
              editAutocompleteDropdown.classList.add('hidden');
              return;
            }
            e.preventDefault();
            saveEditRow(tr, originalValues, row.__account);
          }
        });
        td.appendChild(editAutocompleteDropdown);
      } else {
        // Non-category Enter handler
        input.addEventListener('keydown', (e) => {
          if (e.key === 'Enter') { e.preventDefault(); saveEditRow(tr, originalValues, row.__account); }
        });
      }
      td.appendChild(input);
      tr.appendChild(td);
    });
    // Action buttons cell
    const actionTd = document.createElement('td');
    actionTd.className = 'edit-actions';
    const saveBtn = document.createElement('button');
    saveBtn.className = 'btn primary btn-sm';
    saveBtn.textContent = 'Save';
    saveBtn.addEventListener('click', () => saveEditRow(tr, originalValues));
    const cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn btn-sm edit-cancel-btn';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', () => cancelEdit());
    actionTd.appendChild(saveBtn);
    actionTd.appendChild(cancelBtn);
    tr.appendChild(actionTd);
    // Focus first input
    const firstInput = tr.querySelector('.edit-input');
    if (firstInput) firstInput.focus();
  }

  function cancelEdit() {
    if (!editingRow) return;
    editingRow = null;
    renderFilteredTable();
  }

  async function saveEditRow(tr, originalValues, originalAccount) {
    const headers = getHeaders();
    const inputs = tr.querySelectorAll('.edit-input');
    const newRow = {};
    let newAccount = originalAccount;
    headers.forEach((h, i) => {
      let val = inputs[i].value.trim();
      if (h === 'Amount') {
        let num = parseFloat(val);
        if (isNaN(num)) num = 0;
        const origNum = parseFloat(originalValues.Amount);
        if (!isNaN(origNum) && origNum < 0) num = -Math.abs(num);
        else num = Math.abs(num);
        val = num.toFixed(2);
      } else if (h === 'Account') {
        newAccount = val;
        return; // Don't include Account in the CSV row data
      }
      newRow[h] = val;
    });
    const account = tr.dataset.account;
    const rowIndex = parseInt(tr.dataset.rowIndex, 10);
    try {
      if (newAccount !== account) {
        // First update the row data in the source, then move it
        const updateRes = await fetch('/api/data/' + encodeURIComponent(account) + '/update_row', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ row_index: rowIndex, row: newRow })
        });
        if (updateRes.ok) {
          allData[account] = await updateRes.json();
        }
        // Now move the row
        const moveRes = await fetch('/api/data/' + encodeURIComponent(account) + '/move_rows', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ target_account: newAccount, row_indices: [rowIndex] })
        });
        if (moveRes.ok) {
          const result = await moveRes.json();
          allData[account] = result.source;
          allData[newAccount] = result.target;
          editingRow = null;
          renderFilteredTable();
        }
      } else {
        const res = await fetch('/api/data/' + encodeURIComponent(account) + '/update_row', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ row_index: rowIndex, row: newRow })
        });
        if (res.ok) {
          allData[account] = await res.json();
          editingRow = null;
          renderFilteredTable();
        }
      }
    } catch (err) { console.error('Error updating row:', err); }
  }

  // --- Delete Selected Rows ---
  async function deleteSelectedRows() {
    const checked = tableBodyEl.querySelectorAll('.row-select:checked');
    if (checked.length === 0) return;
    if (!confirm(`Delete ${checked.length} selected row(s)?`)) return;
    // Group by account
    const grouped = {};
    checked.forEach(cb => {
      const tr = cb.closest('tr');
      const account = tr.dataset.account;
      const rowIndex = parseInt(tr.dataset.rowIndex, 10);
      if (!grouped[account]) grouped[account] = [];
      grouped[account].push(rowIndex);
    });
    try {
      for (const [account, indices] of Object.entries(grouped)) {
        const res = await fetch('/api/data/' + encodeURIComponent(account) + '/delete_rows', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ row_indices: indices })
        });
        if (res.ok) {
          allData[account] = await res.json();
        }
      }
      renderFilteredTable();
    } catch (err) { console.error('Error deleting rows:', err); }
  }

  deleteSelectedBtn.addEventListener('click', deleteSelectedRows);

  // --- Change Account for Selected Rows ---
  async function changeSelectedAccount() {
    const checked = tableBodyEl.querySelectorAll('.row-select:checked');
    if (checked.length === 0) return;
    const targetAccount = changeAccountSelect.value;
    if (!confirm(`Move ${checked.length} selected row(s) to ${accountDisplayName(targetAccount)}?`)) return;
    // Group by source account
    const grouped = {};
    checked.forEach(cb => {
      const tr = cb.closest('tr');
      const account = tr.dataset.account;
      const rowIndex = parseInt(tr.dataset.rowIndex, 10);
      if (account === targetAccount) return; // skip if already in target
      if (!grouped[account]) grouped[account] = [];
      grouped[account].push(rowIndex);
    });
    try {
      for (const [sourceAccount, indices] of Object.entries(grouped)) {
        const res = await fetch('/api/data/' + encodeURIComponent(sourceAccount) + '/move_rows', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ target_account: targetAccount, row_indices: indices })
        });
        if (res.ok) {
          const result = await res.json();
          allData[sourceAccount] = result.source;
          allData[targetAccount] = result.target;
        }
      }
      renderFilteredTable();
    } catch (err) { console.error('Error moving rows:', err); }
  }

  changeAccountBtn.addEventListener('click', changeSelectedAccount);

  // --- Filter Apply / Reset ---
  filterApplyBtn.addEventListener('click', () => { renderFilteredTable(); });

  filterResetBtn.addEventListener('click', () => {
    filterCategoryEl.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = true);
    filterDescription.value = '';
    filterAmountMin.value = '';
    filterAmountMax.value = '';
    filterDateStart.value = '';
    filterDateEnd.value = '';
    renderFilteredTable();
  });

  // --- Category Select All / Deselect All ---
  document.getElementById('cat-select-all').addEventListener('click', () => {
    filterCategoryEl.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = true);
    renderFilteredTable();
  });
  document.getElementById('cat-deselect-all').addEventListener('click', () => {
    filterCategoryEl.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = false);
    renderFilteredTable();
  });

  // --- Autocomplete ---
  function getCategories() { return isExpense ? EXPENSE_CATEGORIES : INCOME_CATEGORIES; }

  function updateAutocompleteSuggestions() {
    const val = inputCategory.value.toLowerCase().trim();
    const cats = getCategories();
    const matches = val ? cats.filter(c => c.toLowerCase().startsWith(val)) : [];
    if (matches.length === 0) {
      autocompleteDropdown.classList.add('hidden');
      autocompleteDropdown.innerHTML = '';
      autocompleteIndex = -1;
      return;
    }
    autocompleteDropdown.classList.remove('hidden');
    autocompleteDropdown.innerHTML = '';
    autocompleteIndex = -1;
    matches.forEach(m => {
      const div = document.createElement('div');
      div.className = 'autocomplete-item';
      const color = getCategoryColor(m);
      div.textContent = m;
      div.style.borderLeft = `3px solid ${color.text}`;
      div.addEventListener('mousedown', (e) => {
        e.preventDefault();
        inputCategory.value = m;
        autocompleteDropdown.classList.add('hidden');
      });
      autocompleteDropdown.appendChild(div);
    });
  }

  inputCategory.addEventListener('input', updateAutocompleteSuggestions);
  inputCategory.addEventListener('focus', updateAutocompleteSuggestions);
  inputCategory.addEventListener('blur', () => {
    setTimeout(() => autocompleteDropdown.classList.add('hidden'), 150);
  });
  inputCategory.addEventListener('keydown', (e) => {
    const items = autocompleteDropdown.querySelectorAll('.autocomplete-item');
    if (items.length === 0) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      autocompleteIndex = Math.min(autocompleteIndex + 1, items.length - 1);
      items.forEach((it, i) => it.classList.toggle('active', i === autocompleteIndex));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      autocompleteIndex = Math.max(autocompleteIndex - 1, 0);
      items.forEach((it, i) => it.classList.toggle('active', i === autocompleteIndex));
    } else if (e.key === 'Tab') {
      if (!autocompleteDropdown.classList.contains('hidden') && items.length > 0) {
        const idx = autocompleteIndex >= 0 ? autocompleteIndex : 0;
        inputCategory.value = items[idx].textContent;
        autocompleteDropdown.classList.add('hidden');
      }
    }
  });

  // --- Submit Row ---
  async function submitRow() {
    const date = inputDate.value;
    const description = inputDescription.value.trim();
    const category = inputCategory.value.trim();
    let amount = parseFloat(inputAmount.value);
    if (!date || !description || !category || isNaN(amount)) {
      const bar = document.querySelector('.input-bar');
      bar.style.borderTopColor = 'var(--danger)';
      setTimeout(() => bar.style.borderTopColor = '', 600);
      return;
    }
    amount = Math.abs(amount);
    if (isExpense) amount = -amount;
    const filename = inputAccount.value;
    const row = { Date: date, Description: description, Category: category, Amount: amount.toFixed(2) };
    try {
      const res = await fetch('/api/data/' + encodeURIComponent(filename) + '/add_row', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ row })
      });
      if (res.ok) {
        allData[filename] = await res.json();
        renderFilteredTable();
        document.querySelector('.content-area').scrollTop = document.querySelector('.content-area').scrollHeight;
        inputDescription.value = '';
        inputCategory.value = '';
        inputAmount.value = '';
        inputDescription.focus();
        setDefaultDate();
      }
    } catch (err) { console.error('Error submitting row:', err); }
  }

  submitBtn.addEventListener('click', submitRow);

  // --- Keyboard Navigation ---
  const inputBarFields = [inputDate, inputDescription, inputCategory, inputAmount];
  inputBarFields.forEach(field => {
    field.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        if (field === inputCategory && !autocompleteDropdown.classList.contains('hidden')) {
          const items = autocompleteDropdown.querySelectorAll('.autocomplete-item');
          if (items.length > 0) {
            const idx = autocompleteIndex >= 0 ? autocompleteIndex : 0;
            inputCategory.value = items[idx].textContent;
            autocompleteDropdown.classList.add('hidden');
            return;
          }
        }
        submitRow();
      }
    });
  });

  // --- Apply category colors to filter checkboxes ---
  filterCategoryEl.querySelectorAll('.checkbox-label').forEach(label => {
    const cb = label.querySelector('input[type="checkbox"]');
    if (cb) {
      const color = getCategoryColor(cb.value);
      label.style.setProperty('--cat-color-bg', color.bg);
      label.style.setProperty('--cat-color-text', color.text);
      label.style.setProperty('--cat-color-border', color.border);
    }
  });

  // --- Initial Load ---
  Promise.all(ACCOUNT_FILES.map(f => loadAccount(f))).then(() => {
    renderFilteredTable();
    setDefaultDate();
  });
});
