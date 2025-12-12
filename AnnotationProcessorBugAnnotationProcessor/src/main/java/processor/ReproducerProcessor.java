package processor;

import java.util.Set;
import java.util.function.BinaryOperator;

import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.lang.model.element.Element;
import javax.lang.model.element.ElementKind;
import javax.lang.model.element.ExecutableElement;
import javax.lang.model.element.TypeElement;
import javax.lang.model.type.DeclaredType;
import javax.lang.model.type.TypeKind;
import javax.lang.model.type.TypeMirror;
import javax.lang.model.util.ElementFilter;

public class ReproducerProcessor extends AbstractProcessor {

	@Override
	public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
		TypeElement annotationType = processingEnv.getElementUtils().getTypeElement("test.ReproduceIssue");
		
		for (ExecutableElement e : ElementFilter.methodsIn(roundEnv.getElementsAnnotatedWith(annotationType))) {
			TypeMirror returnType = e.getReturnType();
			if (returnType.getKind() == TypeKind.DECLARED) {
				Element declaredElement = ((DeclaredType)returnType).asElement();
				if (declaredElement.getKind() == ElementKind.CLASS) {
					TypeElement typeElement = (TypeElement)declaredElement;
					
					ExecutableElement singleMethod = null;
					for (ExecutableElement binaryExecutable : ElementFilter.methodsIn(typeElement.getEnclosedElements())) {
						singleMethod = binaryExecutable;
					}
					
					if (singleMethod == null) {
						throw new AssertionError("method not found");
					}
					
					DeclaredType singleMethodReturn = (DeclaredType)singleMethod.getReturnType();
					TypeElement type = (TypeElement)singleMethodReturn.asElement();
					Element enclosing = type.getEnclosingElement();
					
					if (enclosing.getKind() != ElementKind.CLASS) {
						processingEnv.getMessager().printError("Expected a class enclosing element bug got kind " + enclosing.getKind() + ": " + enclosing, e);
					} else {
						return true;
					}
				}
			}
		}
		processingEnv.getMessager().printError("Element not found");
		return true;
	}
	
	@Override
	public Set<String> getSupportedAnnotationTypes() {
		return Set.of("test.ReproduceIssue");
	}

}
