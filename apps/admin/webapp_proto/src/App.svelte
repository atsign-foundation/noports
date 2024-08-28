<script>
    import logoNoPorts from './assets/noports.jpg';
    import logoAtSign from './assets/atsign.svg';
    import PolicyUserGroups from './lib/PolicyUserGroups.svelte';
    let value=1;
    let depth=1;
</script>

<div class="container">
    <h1 style="color: darkorange"><img src={logoNoPorts} alt="AtSign NoPorts" height="35px"/> Policy Manager</h1>

    <hr/>

    <PolicyUserGroups />

    <footer class="d-flex flex-wrap justify-content-between align-items-center py-3 my-4 border-top">
        <div class="col-md-4 d-flex align-items-center">
            <span class="mb-3 mb-md-0 text-body-secondary">&copy; 2024&nbsp;&nbsp;</span>
            <img src={logoAtSign} alt="AtSign NoPorts" height="25px"/>
        </div>
    </footer>
</div>
