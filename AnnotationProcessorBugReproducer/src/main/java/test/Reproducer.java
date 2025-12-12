package test;

import dependency.OtherClass;

public class Reproducer {

	@ReproduceIssue // trigger processor
	public OtherClass foo() {
		return null;
	}
	
	
}
