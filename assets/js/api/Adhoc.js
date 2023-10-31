export async function getAdhoc(str) {
    let request = await fetch(`/n/api/v1/adhoc?string=${str}`);
    let assignments = await request.json();
    return assignments;
}
