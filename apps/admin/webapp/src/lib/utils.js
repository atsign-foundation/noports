export default {
    loadData: async function loadData(url) {
        const res = await fetch(url);
        const resText = await res.text();
        if (!res.ok) {
            if (resText) {
                throw new Error(resText);
            } else {
                throw new Error(`${res.statusText}`);
            }
        }

        let obj = JSON.parse(resText);

        return obj;
    },

    saveData: async function saveData(method, url, obj) {
        const res = await fetch(url, {
            method: method,
            headers: {
                Accept: 'application.json',
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify(obj),
            cache: 'default'
        });
        const resText = await res.text();
        if (!res.ok) {
            if (resText) {
                throw new Error(resText);
            } else {
                throw new Error(`${res.statusText}`);
            }
        }
        return JSON.parse(resText);
    },

    deleteData: async function deleteData(url) {
        const res = await fetch(url, {
            method: 'DELETE',
            headers: {
                Accept: 'application.json',
                'Content-Type': 'application/json; charset=UTF-8'
            },
        });
        const resText = await res.text();
        if (!res.ok) {
            if (resText) {
                throw new Error(resText);
            } else {
                throw new Error(`${res.statusText}`);
            }
        }
    }
}