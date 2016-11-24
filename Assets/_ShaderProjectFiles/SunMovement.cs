using UnityEngine;
using System.Collections;

public class SunMovement : MonoBehaviour {

	// Use this for initialization
	void Start () {
	
	}

    public float speed = 1;
	// Update is called once per frame
	void Update () {
        transform.Rotate(Vector3.right, Time.deltaTime * speed);
	}
}
